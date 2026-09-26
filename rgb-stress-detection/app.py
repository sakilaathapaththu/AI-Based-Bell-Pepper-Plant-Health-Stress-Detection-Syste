"""
AI-Based RGB Bell Pepper Plant Stress Detection - FastAPI inference service.

Loads the artifacts produced by train.py (model/model_metadata.json, plus
either model/stage1_final.keras + model/stage2_final.keras for the
two-stage cascade, or model/flat_model_final.keras for the flat model) and
serves the exact flow described in the project scenario:

    1. Photo upload -> classical image-quality gate (quality_gate.py).
       If it fails: reject with "Image unclear. Please retake the image."
    2. If quality passes -> deep model inference:
         Stage 1: Healthy vs Stressed
         Stage 2 (only if Stressed): which stress/cause type
    3. Response includes Plant Condition, Stress Type, Severity (heuristic
       proxy - see analysis doc Section 5.1), Confidence, and a
       recovery_handoff payload matching the "Send to Recovery System"
       button in the UI flow.

Uses the exact same preprocessing function as train.py/data_pipeline.py
(preprocess_image_bytes) - never reimplemented here - to avoid train/serve
skew.

Run with:
    uvicorn app:app --reload

Requires model/ to already contain trained artifacts (run train.py first).
"""

from __future__ import annotations

import json
import tempfile
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, HTTPException, UploadFile

import config
import model  # noqa: F401 - import registers the custom preprocessing functions with Keras before load_model() is called
from data_pipeline import preprocess_image_bytes
from quality_gate import assess_image_quality

MODEL_VERSION = "rgb-bellpepper-stress-v1"


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_artifacts()
    yield


app = FastAPI(title="AI-Based RGB Bell Pepper Plant Stress Detection API", lifespan=lifespan)


class Artifacts:
    metadata: dict | None = None
    training_mode: str | None = None
    stage1_model = None  # Healthy vs Stressed
    stage2_model = None  # stress type among non-Healthy classes
    stage2_class_names: list[str] | None = None
    flat_model = None
    flat_class_names: list[str] | None = None


def load_artifacts() -> None:
    metadata_path = config.ARTIFACT_DIR / "model_metadata.json"
    if not metadata_path.exists():
        # Do not crash at import time - let /health report the problem so
        # the API can still start during development before training runs.
        return

    Artifacts.metadata = json.loads(metadata_path.read_text())
    Artifacts.training_mode = Artifacts.metadata["training_mode"]

    if Artifacts.training_mode == "two_stage_cascade":
        stage1_path = config.ARTIFACT_DIR / "stage1_final.keras"
        stage2_path = config.ARTIFACT_DIR / "stage2_final.keras"
        if stage1_path.exists() and stage2_path.exists():
            Artifacts.stage1_model = tf.keras.models.load_model(stage1_path, compile=False)
            Artifacts.stage2_model = tf.keras.models.load_model(stage2_path, compile=False)
            Artifacts.stage2_class_names = Artifacts.metadata["stage2_class_names"]
    else:
        flat_path = config.ARTIFACT_DIR / "flat_model_final.keras"
        if flat_path.exists():
            Artifacts.flat_model = tf.keras.models.load_model(flat_path, compile=False)
            Artifacts.flat_class_names = Artifacts.metadata["flat_class_names"]


def artifacts_ready() -> bool:
    if Artifacts.metadata is None:
        return False
    if Artifacts.training_mode == "two_stage_cascade":
        return Artifacts.stage1_model is not None and Artifacts.stage2_model is not None
    return Artifacts.flat_model is not None


def severity_from_confidence(confidence: float) -> str:
    """Heuristic proxy only - NOT an expert-validated severity label.

    The dataset has no severity annotations (see analysis doc Section 5.1).
    This buckets the model's own confidence margin into Mild/Moderate/Severe
    as a stand-in until real severity/affected-area labels are collected.
    Report this bucketing method explicitly wherever severity is shown.
    """
    if confidence < 0.60:
        return "Mild"
    if confidence < 0.85:
        return "Moderate"
    return "Severe"


def run_inference(image_tensor: tf.Tensor) -> dict:
    batch = tf.expand_dims(image_tensor, axis=0)

    if Artifacts.training_mode == "two_stage_cascade":
        stressed_probability = float(Artifacts.stage1_model.predict(batch, verbose=0)[0][0])
        is_stressed = stressed_probability >= 0.5

        if not is_stressed:
            return {
                "plant_condition": "Healthy",
                "stress_type": None,
                "severity": None,
                "confidence": round(1.0 - stressed_probability, 4),
            }

        stage2_probs = Artifacts.stage2_model.predict(batch, verbose=0)[0]
        class_index = int(np.argmax(stage2_probs))
        confidence = float(stage2_probs[class_index])
        stress_type = Artifacts.stage2_class_names[class_index]

        return {
            "plant_condition": "Stressed",
            "stress_type": stress_type,
            "severity": severity_from_confidence(confidence),
            "confidence": round(confidence, 4),
        }

    probs = Artifacts.flat_model.predict(batch, verbose=0)[0]
    class_index = int(np.argmax(probs))
    confidence = float(probs[class_index])
    predicted_class = Artifacts.flat_class_names[class_index]
    is_healthy = predicted_class == config.HEALTHY_CLASS_NAME

    return {
        "plant_condition": "Healthy" if is_healthy else "Stressed",
        "stress_type": None if is_healthy else predicted_class,
        "severity": None if is_healthy else severity_from_confidence(confidence),
        "confidence": round(confidence, 4),
    }


@app.get("/health")
def health() -> dict:
    return {
        "artifacts_loaded": artifacts_ready(),
        "training_mode": Artifacts.training_mode,
        "model_version": Artifacts.metadata.get("model_version") if Artifacts.metadata else None,
    }


@app.post("/predict")
async def predict(image: UploadFile = File(...)) -> dict:
    if not artifacts_ready():
        raise HTTPException(
            status_code=503,
            detail="Model artifacts not found under model/. Run train.py first.",
        )

    image_bytes = await image.read()

    # Step 1: classical image-quality gate, matching the app's
    # "Image unclear. Please retake the image." message - runs BEFORE the
    # deep model, using the same rejection reasons as quality_gate.py.
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=True) as tmp:
        tmp.write(image_bytes)
        tmp.flush()
        quality = assess_image_quality(tmp.name)

    if not quality["accepted"]:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "Image unclear. Please retake the image.",
                "reason": quality["reason"],
                "metrics": quality.get("metrics"),
            },
        )

    # Step 2: preprocess with the exact same function used at training time
    # (data_pipeline.preprocess_image_bytes) - never reimplemented here.
    try:
        image_tensor = preprocess_image_bytes(image_bytes)
    except tf.errors.InvalidArgumentError as exc:
        raise HTTPException(status_code=422, detail=f"Could not decode image: {exc}") from exc

    result = run_inference(image_tensor)

    return {
        **result,
        "model_version": Artifacts.metadata.get("model_version"),
        "severity_method": (
            "heuristic proxy from model confidence - not an expert-validated "
            "severity label (see analysis doc Section 5.1)"
            if result["severity"] is not None
            else None
        ),
        "recovery_handoff": {
            "stress_type": result["stress_type"],
            "severity": result["severity"],
            "confidence": result["confidence"],
        } if result["plant_condition"] == "Stressed" else None,
    }


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   uvicorn app:app --reload
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
