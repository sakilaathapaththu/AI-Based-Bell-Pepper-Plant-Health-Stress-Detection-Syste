"""
Thermal stress-evidence inference service.

Ported from Thermal-stress-evidence-identify/app.py + data_pipeline.py +
quality_gate.py + feature_extraction.py + model.py.
"""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import cv2
import joblib
import keras
import numpy as np
import tensorflow as tf
from scipy.stats import skew

MODEL_DIR = Path(__file__).resolve().parent.parent / "models" / "thermal"

IMAGE_SIZE = (240, 320)  # (height, width)
CHANNELS = 3
HEALTHY_CLASS_NAME = "Healthy"

BLUR_LAPLACIAN_VAR_THRESHOLD = 50.0
MIN_PIXEL_STD = 8.0
ENV_CONFOUND_DIFF_THRESHOLD = 5.0


@keras.saving.register_keras_serializable(package="thermal_stress_detection", name="efficientnet_preprocess")
def _efficientnet_preprocess(x):
    return tf.keras.applications.efficientnet.preprocess_input(x)


@keras.saving.register_keras_serializable(package="thermal_stress_detection", name="mobilenetv3_preprocess")
def _mobilenetv3_preprocess(x):
    return tf.keras.applications.mobilenet_v3.preprocess_input(x)


class Artifacts:
    metadata: dict | None = None
    class_names: list[str] | None = None
    track_a_model = None
    track_b_model = None


def load_artifacts() -> None:
    metadata_path = MODEL_DIR / "model_metadata.json"
    if not metadata_path.exists():
        return

    Artifacts.metadata = json.loads(metadata_path.read_text())
    Artifacts.class_names = Artifacts.metadata["flat_class_names"]

    model_path = MODEL_DIR / "track_a_final.keras"
    if model_path.exists():
        Artifacts.track_a_model = tf.keras.models.load_model(model_path, compile=False)

    track_b_path = MODEL_DIR / "track_b_classifier.pkl"
    if track_b_path.exists():
        Artifacts.track_b_model = joblib.load(track_b_path)


def artifacts_ready() -> bool:
    return Artifacts.metadata is not None and Artifacts.track_a_model is not None


def assess_image_quality(image_path: str) -> dict:
    image = cv2.imread(image_path)
    if image is None:
        return {"accepted": False, "reason": "unreadable_file"}

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blur = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    std = float(np.std(gray))

    result = {"accepted": True, "reason": None, "metrics": {"blur_score": blur, "pixel_std": std}}

    if blur < BLUR_LAPLACIAN_VAR_THRESHOLD:
        result["accepted"] = False
        result["reason"] = "blurry"
    elif std < MIN_PIXEL_STD:
        result["accepted"] = False
        result["reason"] = "flat_or_stuck_sensor_frame"

    return result


def to_intensity_proxy(image_path: str) -> np.ndarray:
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(f"Could not read image: {image_path}")
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return gray.astype(np.float32)


def segment_plant_region(intensity: np.ndarray) -> np.ndarray:
    valid_mask = intensity > 0
    valid_pixels = intensity[valid_mask]
    if valid_pixels.size == 0:
        return np.zeros_like(intensity, dtype=bool)

    otsu_threshold, _ = cv2.threshold(valid_pixels.astype(np.uint8), 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return valid_mask & (intensity >= otsu_threshold)


def extract_features(image_path: str) -> dict:
    intensity = to_intensity_proxy(image_path)
    mask = segment_plant_region(intensity)
    region_pixels = intensity[mask]
    background_pixels = intensity[~mask]

    if region_pixels.size == 0:
        region_pixels = intensity.flatten()
    if background_pixels.size == 0:
        background_pixels = intensity.flatten()

    foreground_mean = float(np.mean(region_pixels))
    background_mean = float(np.mean(background_pixels))

    return {
        "proxy_mean": foreground_mean,
        "proxy_min": float(np.min(region_pixels)),
        "proxy_max": float(np.max(region_pixels)),
        "proxy_range": float(np.max(region_pixels) - np.min(region_pixels)),
        "proxy_std": float(np.std(region_pixels)),
        "proxy_skewness": float(skew(region_pixels)) if region_pixels.size > 2 else 0.0,
        "foreground_pixel_ratio": float(mask.mean()),
        "whole_frame_mean": float(np.mean(intensity)),
        "whole_frame_std": float(np.std(intensity)),
        "background_mean": background_mean,
        "foreground_background_diff": float(abs(foreground_mean - background_mean)),
    }


def preprocess_image_bytes(image_bytes: bytes) -> tf.Tensor:
    image = tf.image.decode_png(image_bytes, channels=CHANNELS)
    image = tf.image.resize(image, IMAGE_SIZE, method="bilinear")
    image = tf.cast(image, tf.float32)
    return image / 255.0


def severity_from_confidence(confidence: float) -> str:
    if confidence < 0.60:
        return "Mild"
    if confidence < 0.85:
        return "Moderate"
    return "Severe"


def predict(image_bytes: bytes, plant_id: str | None = None) -> dict:
    if not artifacts_ready():
        raise RuntimeError("Thermal model artifacts not loaded. Check app/models/thermal/.")

    with tempfile.NamedTemporaryFile(suffix=".png", delete=True) as tmp:
        tmp.write(image_bytes)
        tmp.flush()
        quality = assess_image_quality(tmp.name)

        if not quality["accepted"]:
            raise ValueError(json.dumps({
                "message": "Image unclear or invalid thermal data. Please retake the image.",
                "reason": quality["reason"],
                "metrics": quality.get("metrics"),
            }))

        thermal_features = extract_features(tmp.name)

    image_tensor = preprocess_image_bytes(image_bytes)
    batch = tf.expand_dims(image_tensor, axis=0)
    probs = Artifacts.track_a_model.predict(batch, verbose=0)[0]
    class_index = int(np.argmax(probs))
    confidence = float(probs[class_index])
    predicted_class = Artifacts.class_names[class_index]
    is_healthy = predicted_class == HEALTHY_CLASS_NAME

    possible_environmental_confound = thermal_features["foreground_background_diff"] < ENV_CONFOUND_DIFF_THRESHOLD

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
            "heuristic proxy from model confidence - not an expert-validated severity label"
            if not is_healthy
            else None
        ),
    }
