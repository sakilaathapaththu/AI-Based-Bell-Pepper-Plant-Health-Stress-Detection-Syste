"""
RGB stress-detection inference service.

Ported from rgb-stress-detection/app.py + data_pipeline.py + quality_gate.py
+ model.py - same preprocessing/thresholds, loaded directly in this process
instead of calling a separate FastAPI service.
"""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import cv2
import keras
import numpy as np
import tensorflow as tf

MODEL_DIR = Path(__file__).resolve().parent.parent / "models" / "rgb"

IMAGE_SIZE = (256, 256)
CHANNELS = 3
HEALTHY_CLASS_NAME = "Healthy"

BLUR_LAPLACIAN_VAR_THRESHOLD = 100.0
MIN_MEAN_BRIGHTNESS = 40.0
MAX_MEAN_BRIGHTNESS = 220.0
MIN_FOLIAGE_PIXEL_RATIO = 0.05


@keras.saving.register_keras_serializable(package="rgb_stress_detection", name="efficientnet_preprocess")
def _efficientnet_preprocess(x):
    return tf.keras.applications.efficientnet.preprocess_input(x)


@keras.saving.register_keras_serializable(package="rgb_stress_detection", name="mobilenetv3_preprocess")
def _mobilenetv3_preprocess(x):
    return tf.keras.applications.mobilenet_v3.preprocess_input(x)


class Artifacts:
    metadata: dict | None = None
    training_mode: str | None = None
    stage1_model = None
    stage2_model = None
    stage2_class_names: list[str] | None = None
    flat_model = None
    flat_class_names: list[str] | None = None


def load_artifacts() -> None:
    metadata_path = MODEL_DIR / "model_metadata.json"
    if not metadata_path.exists():
        return

    Artifacts.metadata = json.loads(metadata_path.read_text())
    Artifacts.training_mode = Artifacts.metadata["training_mode"]

    if Artifacts.training_mode == "two_stage_cascade":
        stage1_path = MODEL_DIR / "stage1_final.keras"
        stage2_path = MODEL_DIR / "stage2_final.keras"
        if stage1_path.exists() and stage2_path.exists():
            Artifacts.stage1_model = tf.keras.models.load_model(stage1_path, compile=False)
            Artifacts.stage2_model = tf.keras.models.load_model(stage2_path, compile=False)
            Artifacts.stage2_class_names = Artifacts.metadata["stage2_class_names"]
    else:
        flat_path = MODEL_DIR / "flat_model_final.keras"
        if flat_path.exists():
            Artifacts.flat_model = tf.keras.models.load_model(flat_path, compile=False)
            Artifacts.flat_class_names = Artifacts.metadata["flat_class_names"]


def artifacts_ready() -> bool:
    if Artifacts.metadata is None:
        return False
    if Artifacts.training_mode == "two_stage_cascade":
        return Artifacts.stage1_model is not None and Artifacts.stage2_model is not None
    return Artifacts.flat_model is not None


def assess_image_quality(image_path: str) -> dict:
    bgr_image = cv2.imread(image_path)
    if bgr_image is None:
        return {"accepted": False, "reason": "unreadable_file"}

    gray = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2GRAY)
    blur = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    brightness = float(np.mean(gray))

    hsv = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, np.array([20, 25, 25]), np.array([95, 255, 255]))
    foliage_ratio = float(np.count_nonzero(mask)) / mask.size

    result = {
        "accepted": True,
        "reason": None,
        "metrics": {"blur_score": blur, "brightness": brightness, "foliage_ratio": foliage_ratio},
    }

    if blur < BLUR_LAPLACIAN_VAR_THRESHOLD:
        result["accepted"] = False
        result["reason"] = "blurry"
    elif brightness < MIN_MEAN_BRIGHTNESS:
        result["accepted"] = False
        result["reason"] = "too_dark"
    elif brightness > MAX_MEAN_BRIGHTNESS:
        result["accepted"] = False
        result["reason"] = "overexposed"
    elif foliage_ratio < MIN_FOLIAGE_PIXEL_RATIO:
        result["accepted"] = False
        result["reason"] = "no_plant_detected"

    return result


def preprocess_image_bytes(image_bytes: bytes) -> tf.Tensor:
    image = tf.image.decode_jpeg(image_bytes, channels=CHANNELS)
    image = tf.image.resize(image, IMAGE_SIZE, method="bilinear")
    image = tf.cast(image, tf.float32)
    return image / 255.0


def severity_from_confidence(confidence: float) -> str:
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
    is_healthy = predicted_class == HEALTHY_CLASS_NAME

    return {
        "plant_condition": "Healthy" if is_healthy else "Stressed",
        "stress_type": None if is_healthy else predicted_class,
        "severity": None if is_healthy else severity_from_confidence(confidence),
        "confidence": round(confidence, 4),
    }


def predict(image_bytes: bytes) -> dict:
    if not artifacts_ready():
        raise RuntimeError("RGB model artifacts not loaded. Check app/models/rgb/.")

    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=True) as tmp:
        tmp.write(image_bytes)
        tmp.flush()
        quality = assess_image_quality(tmp.name)

    if not quality["accepted"]:
        raise ValueError(json.dumps({
            "message": "Image unclear. Please retake the image.",
            "reason": quality["reason"],
            "metrics": quality.get("metrics"),
        }))

    image_tensor = preprocess_image_bytes(image_bytes)
    result = run_inference(image_tensor)

    return {
        **result,
        "model_version": Artifacts.metadata.get("model_version"),
        "severity_method": (
            "heuristic proxy from model confidence - not an expert-validated severity label"
            if result["severity"] is not None
            else None
        ),
        "recovery_handoff": {
            "stress_type": result["stress_type"],
            "severity": result["severity"],
            "confidence": result["confidence"],
        } if result["plant_condition"] == "Stressed" else None,
    }
