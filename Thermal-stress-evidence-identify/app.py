"""
Thermal-based Bell Pepper Stress Evidence component - FastAPI inference
service.

Implements the flow described for this component:
    Thermal Camera / dataset replay -> Image Quality Check -> Preprocessing
    -> plant-region separation -> thermal feature extraction -> AI model
    (Track A CNN) -> Stress Status + Stress Type + Severity -> standardized
    thermal evidence output -> sent to Component 4 (Adaptive Recovery
    Decision Support System) via API.

This component's responsibility ENDS at producing standardized evidence -
it never recommends a recovery action (that is Component 4's job, which
also fuses this output with the RGB component's and the environmental
component's evidence).

Loads the artifacts produced by train.py (model/model_metadata.json,
model/track_a_final.keras) and feature_extraction.py (model/
track_b_metadata.json, model/track_b_classifier.pkl - used only to populate
the standardized thermal_metrics fields, not as the primary classifier).

Uses the exact same preprocessing function as train.py/data_pipeline.py
(preprocess_image_bytes) and the exact same feature-extraction function as
feature_extraction.py (extract_features_from_array) - never reimplemented
here - to avoid train/serve skew.

Run with:
    uvicorn app:app --reload

Requires model/ to already contain trained artifacts (run train.py and
feature_extraction.py first).
"""

from __future__ import annotations

import json
import tempfile
from contextlib import asynccontextmanager

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, Form, HTTPException, UploadFile

import config
import model  # noqa: F401 - import registers the custom preprocessing functions with Keras before load_model() is called
from data_pipeline import preprocess_image_bytes
from feature_extraction import extract_features
from quality_gate import assess_image_quality

MODEL_VERSION = "thermal-bellpepper-stress-v1"


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_artifacts()
    yield


app = FastAPI(title="Thermal-Based Bell Pepper Plant Stress Evidence API", lifespan=lifespan)


class Artifacts:
    metadata: dict | None = None
    class_names: list[str] | None = None
    track_a_model = None


def load_artifacts() -> None:
    metadata_path = config.ARTIFACT_DIR / "model_metadata.json"
    if not metadata_path.exists():
        # Do not crash at import time - let /health report the problem so
        # the API can still start during development before training runs.
        return

    Artifacts.metadata = json.loads(metadata_path.read_text())
    Artifacts.class_names = Artifacts.metadata["flat_class_names"]

    model_path = config.ARTIFACT_DIR / "track_a_final.keras"
    if model_path.exists():
        Artifacts.track_a_model = tf.keras.models.load_model(model_path, compile=False)


def artifacts_ready() -> bool:
    return Artifacts.metadata is not None and Artifacts.track_a_model is not None


def severity_from_confidence(confidence: float) -> str:
    """Heuristic proxy only - NOT an expert-validated severity label. No
    severity ground-truth exists in this dataset either (see analysis doc
    Section 4, step 5). Bucketed from the model's own confidence margin
    until real severity annotation is available."""
    if confidence < 0.60:
        return "Mild"
    if confidence < 0.85:
        return "Moderate"
    return "Severe"


@app.get("/health")
def health() -> dict:
    return {
        "artifacts_loaded": artifacts_ready(),
        "model_version": Artifacts.metadata.get("model_version") if Artifacts.metadata else None,
    }


@app.post("/predict")
async def predict(
    thermal_image: UploadFile = File(...),
    plant_id: str | None = Form(None),
) -> dict:
    """Accepts one thermal frame (PNG) and returns the standardized thermal
    evidence payload meant for Component 4. plant_id is optional here - it
    plays no role in the model itself (training never sees it), it only
    tags the output for whoever consumes it downstream."""
    if not artifacts_ready():
        raise HTTPException(
            status_code=503,
            detail="Model artifacts not found under model/. Run train.py first.",
        )

    image_bytes = await thermal_image.read()

    # Step 1: classical image-quality gate - runs BEFORE the deep model.
    with tempfile.NamedTemporaryFile(suffix=".png", delete=True) as tmp:
        tmp.write(image_bytes)
        tmp.flush()
        quality = assess_image_quality(tmp.name)

        if not quality["accepted"]:
            raise HTTPException(
                status_code=422,
                detail={
                    "message": "Image unclear or invalid thermal data. Please retake the image.",
                    "reason": quality["reason"],
                    "metrics": quality.get("metrics"),
                },
            )

        # Step 2: thermal feature extraction (Track B proxy features) -
        # reuses feature_extraction.extract_features exactly as used at
        # training time, so the standardized output's thermal_metrics are
        # computed identically here and offline.
        thermal_features = extract_features(tmp.name)

    # Step 3: preprocess with the exact same function used at training time.
    try:
        image_tensor = preprocess_image_bytes(image_bytes)
    except tf.errors.InvalidArgumentError as exc:
        raise HTTPException(status_code=422, detail=f"Could not decode image: {exc}") from exc

    # Step 4: Track A CNN classification.
    batch = tf.expand_dims(image_tensor, axis=0)
    probs = Artifacts.track_a_model.predict(batch, verbose=0)[0]
    class_index = int(np.argmax(probs))
    confidence = float(probs[class_index])
    predicted_class = Artifacts.class_names[class_index]
    is_healthy = predicted_class == config.HEALTHY_CLASS_NAME

    # Step 5: "don't assume 100% exact cause" - flag when the temperature
    # pattern isn't localized to the plant, which points at an
    # ambient/environmental effect rather than plant-specific stress
    # (analysis doc Section 4, step 6).
    possible_environmental_confound = (
        thermal_features["foreground_background_diff"] < config.ENV_CONFOUND_DIFF_THRESHOLD
    )

    return {
        "plant_id": plant_id,
        "stress_status": "Healthy" if is_healthy else "Stressed",
        "stress_type": None if is_healthy else predicted_class,
        "severity": None if is_healthy else severity_from_confidence(confidence),
        "model_confidence": round(confidence, 4),
        "thermal_metrics": {
            "mean": round(thermal_features["proxy_mean"], 2),
            "min": round(thermal_features["proxy_min"], 2),
            "max": round(thermal_features["proxy_max"], 2),
            "range": round(thermal_features["proxy_range"], 2),
            "std": round(thermal_features["proxy_std"], 2),
        },
        "thermal_metrics_basis": "pixel_intensity_proxy",
        "possible_environmental_confound": possible_environmental_confound,
        "model_version": Artifacts.metadata.get("model_version"),
        "severity_method": (
            "heuristic proxy from model confidence - not an expert-validated "
            "severity label (see dataset_all/"
            "Thermal_Model_Training_Plan_and_Dataset_Analysis.txt Section 4)"
            if not is_healthy
            else None
        ),
    }


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   uvicorn app:app --reload
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8001)
