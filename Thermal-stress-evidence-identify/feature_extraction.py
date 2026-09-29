"""
Track B: feature-based statistical/ML model (see
dataset_all/Thermal_Model_Training_Plan_and_Dataset_Analysis.txt Section 3).

Extracts per-image statistical "thermal" features from pixel intensity -
mean, min, max, range, std, skewness, foreground-pixel ratio - then trains
a classical ML classifier (Random Forest / XGBoost) on those features.

IMPORTANT - read before trusting these numbers:
    These images are pseudo-color visual thermal renders with NO embedded
    temperature-to-color calibration (no colorbar, no min/max scale, no
    metadata - confirmed by direct pixel inspection). Grayscale pixel
    intensity is used here as a PROXY for relative temperature, not a
    calibrated degrees-Celsius value. Every feature/metric this module
    produces must be reported as "thermal_metrics_basis": "pixel_intensity_
    proxy" downstream (see app.py) until real radiometric data or a known
    palette+scale is obtained (analysis doc Section 2).

The plant/background separation used here (a simple percentile threshold
on pixel intensity, config.FOREGROUND_INTENSITY_PERCENTILE) is a
PLACEHOLDER heuristic, not a validated segmentation model - visually check
a sample of masks (see visualize_mask) before trusting downstream features,
and replace with a trained segmentation model if the heuristic does not
hold up (analysis doc Section 4, step 3 / Section 6, item 3).

This file only DEFINES functions. Nothing runs on import. To extract
features and train Track B, run:

    python feature_extraction.py

which writes features/thermal_features.csv and
model/track_b_classifier.pkl.
"""

from __future__ import annotations

import json

import cv2
import joblib
import numpy as np
import pandas as pd
from scipy.stats import skew
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import StratifiedKFold

try:
    from xgboost import XGBClassifier
except Exception:  # pragma: no cover - xgboost may fail to load on some systems
    XGBClassifier = None

import config
import data_pipeline


def to_intensity_proxy(image_path: str) -> np.ndarray:
    """Loads an image and returns a single-channel intensity array used as
    a PROXY for relative temperature (brighter pixel = higher proxy value).
    Real radiometric calibration would replace this function's output with
    actual per-pixel temperature readings - see module docstring."""
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(f"Could not read image: {image_path}")
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return gray.astype(np.float32)


def segment_plant_region(intensity: np.ndarray) -> np.ndarray:
    """PLACEHOLDER heuristic: separates the plant/foreground region from
    background using Otsu's threshold, computed only over non-zero pixels.

    A plain percentile threshold does NOT work on this dataset: roughly
    two-thirds of pixels in every sample image are exactly 0 (a black
    border/vignette around the thermal frame), so a naive
    config.FOREGROUND_INTENSITY_PERCENTILE-th percentile lands on 0 too,
    making "intensity >= threshold" true for the ENTIRE image (verified by
    direct inspection - do not revert to a plain percentile without
    re-checking this). Excluding the black border first and then applying
    Otsu's method on the remaining pixels avoids that failure mode.

    This still assumes the plant is thermally distinguishable (warmer or
    cooler, whichever renders brighter in the unknown palette) from a more
    uniform background within the non-border area - verify this assumption
    visually (see visualize_mask) before trusting the features below, per
    analysis doc Section 4 step 3."""
    valid_mask = intensity > 0
    valid_pixels = intensity[valid_mask]
    if valid_pixels.size == 0:
        return np.zeros_like(intensity, dtype=bool)

    otsu_threshold, _ = cv2.threshold(
        valid_pixels.astype(np.uint8), 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )
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
        # Small foreground/background contrast suggests the temperature
        # pattern is NOT localized to the plant - i.e. the whole scene is
        # warm/cool together, which points at an ambient/environmental
        # effect rather than plant-specific stress (see app.py's
        # possible_environmental_confound flag and analysis doc Section 4,
        # step 6).
        "foreground_background_diff": float(abs(foreground_mean - background_mean)),
    }


FEATURE_COLUMNS = [
    "proxy_mean",
    "proxy_min",
    "proxy_max",
    "proxy_range",
    "proxy_std",
    "proxy_skewness",
    "foreground_pixel_ratio",
    "whole_frame_mean",
    "whole_frame_std",
    "background_mean",
    "foreground_background_diff",
]


def visualize_mask(image_path: str, out_path: str) -> None:
    """Saves a side-by-side original/mask overlay PNG - use this to
    visually sanity-check the segmentation heuristic on a handful of images
    per class before trusting the extracted features (analysis doc Section
    6, item 3)."""
    image = cv2.imread(image_path)
    intensity = to_intensity_proxy(image_path)
    mask = segment_plant_region(intensity)

    overlay = image.copy()
    overlay[~mask] = overlay[~mask] // 3  # dim the background, keep foreground bright
    combined = np.concatenate([image, overlay], axis=1)
    cv2.imwrite(out_path, combined)


def build_feature_table(manifest: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for _, row in manifest.iterrows():
        features = extract_features(row["filepath"])
        rows.append({"filepath": row["filepath"], "class": row["class"], "split": row["split"], **features})
    return pd.DataFrame(rows)


def train_track_b(feature_table: pd.DataFrame, class_names: list[str]) -> tuple:
    train_df = feature_table[feature_table["split"] == "train"]
    test_df = feature_table[feature_table["split"] == "test"]

    X_train, y_train = train_df[FEATURE_COLUMNS], train_df["class"]
    X_test, y_test = test_df[FEATURE_COLUMNS], test_df["class"]

    candidates = {
        "random_forest": RandomForestClassifier(
            n_estimators=300, class_weight="balanced", random_state=config.RANDOM_SEED
        ),
    }
    if XGBClassifier is not None:
        candidates["xgboost"] = XGBClassifier(
            n_estimators=300, max_depth=4, learning_rate=0.05, eval_metric="logloss", random_state=config.RANDOM_SEED
        )

    best_name, best_model, best_f1 = None, None, -1.0
    all_metrics = {}

    for name, clf in candidates.items():
        clf.fit(X_train, y_train)
        y_pred = clf.predict(X_test)
        report = classification_report(y_test, y_pred, labels=class_names, output_dict=True, zero_division=0)
        macro_f1 = report["macro avg"]["f1-score"]
        print(f"[feature_extraction] {name}: macro-F1 = {macro_f1:.3f}")
        all_metrics[name] = {
            "classification_report": report,
            "confusion_matrix": confusion_matrix(y_test, y_pred, labels=class_names).tolist(),
        }
        if macro_f1 > best_f1:
            best_name, best_model, best_f1 = name, clf, macro_f1

    print(f"[feature_extraction] Selected model: {best_name} (macro-F1 = {best_f1:.3f})")
    return best_model, best_name, all_metrics


def kfold_evaluate(feature_table: pd.DataFrame, class_names: list[str]) -> dict:
    """The whole dataset is modest (500 images total) - stratified k-fold
    gives a more trustworthy macro-F1 estimate than a single small test
    split (analysis doc Section 5)."""
    X = feature_table[FEATURE_COLUMNS]
    y = feature_table["class"]

    skf = StratifiedKFold(n_splits=config.KFOLD_SPLITS, shuffle=True, random_state=config.RANDOM_SEED)
    fold_scores = []

    for fold_idx, (train_idx, test_idx) in enumerate(skf.split(X, y)):
        clf = RandomForestClassifier(n_estimators=300, class_weight="balanced", random_state=config.RANDOM_SEED)
        clf.fit(X.iloc[train_idx], y.iloc[train_idx])
        y_pred = clf.predict(X.iloc[test_idx])
        fold_f1 = f1_score(y.iloc[test_idx], y_pred, average="macro", zero_division=0)
        fold_scores.append(fold_f1)
        print(f"[feature_extraction] k-fold {fold_idx + 1}/{config.KFOLD_SPLITS}: macro-F1 = {fold_f1:.3f}")

    return {"fold_macro_f1": fold_scores, "mean_macro_f1": float(np.mean(fold_scores)), "std_macro_f1": float(np.std(fold_scores))}


def run() -> None:
    manifest = pd.read_csv(config.SPLITS_DIR / "manifest.csv")
    class_names = sorted(manifest["class"].unique().tolist())

    print("[feature_extraction] Extracting proxy thermal features for all images...")
    feature_table = build_feature_table(manifest)

    config.FEATURES_DIR.mkdir(parents=True, exist_ok=True)
    features_path = config.FEATURES_DIR / "thermal_features.csv"
    feature_table.to_csv(features_path, index=False)
    print(f"[feature_extraction] Wrote {len(feature_table)} rows to {features_path}")

    best_model, best_name, holdout_metrics = train_track_b(feature_table, class_names)
    kfold_metrics = kfold_evaluate(feature_table, class_names)

    config.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(best_model, config.ARTIFACT_DIR / "track_b_classifier.pkl")

    metadata = {
        "model_name": best_name,
        "class_names": class_names,
        "feature_columns": FEATURE_COLUMNS,
        "thermal_metrics_basis": "pixel_intensity_proxy",
        "holdout_metrics": holdout_metrics,
        "kfold_metrics": kfold_metrics,
    }
    (config.ARTIFACT_DIR / "track_b_metadata.json").write_text(json.dumps(metadata, indent=2))
    print(f"[feature_extraction] Track B artifacts saved to {config.ARTIFACT_DIR}")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python feature_extraction.py
    run()
