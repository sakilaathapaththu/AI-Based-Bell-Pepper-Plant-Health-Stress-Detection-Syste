"""
Environmental Stress Prediction - training pipeline.

Single-file training script following the workflow required in agent.md
(Section 24): load -> validate -> clean -> label -> feature-engineer ->
split -> train baselines + candidates -> calibrate -> evaluate -> explain
-> save artifacts to model/.

This file only DEFINES the pipeline. Nothing runs on import. To actually
train, run:

    python train.py

which will read Dataset/model_training_table.csv, fit models, and write
artifacts into model/.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.dummy import DummyClassifier, DummyRegressor
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix, mean_absolute_error

try:
    from xgboost import XGBClassifier, XGBRegressor
except Exception:
    # xgboost may be installed but fail to *load* (e.g. missing libomp on
    # macOS) - either way, fall back to Random Forest as the baseline.
    XGBClassifier = None
    XGBRegressor = None

BASE_DIR = Path(__file__).resolve().parent
DATASET_PATH = BASE_DIR / "Dataset" / "model_training_table.csv"
LABELS_MANUAL_PATH = BASE_DIR / "labels_manual.csv"
MODEL_DIR = BASE_DIR / "model"

RANDOM_SEED = 42

TIMESTAMP_COL = "timestamp"
GROWTH_STAGE_COL = "growth_stage"
SENSOR_COLUMNS = [
    "air_temperature_c",
    "relative_humidity_pct",
    "light_intensity_lux",
    "soil_temperature_c",
]
SPLIT_COL = "split"

# 30-minute-ahead and 60-minute-ahead targets, already provided by the
# dataset (see Dataset/model_training_table.csv columns).
TARGETS = {
    30: {"risk_level": "risk_level_30m", "risk_score": "risk_score_30m", "stress_type": "stress_type_30m"},
    60: {"risk_level": "risk_level_60m", "risk_score": "risk_score_60m", "stress_type": "stress_type_60m"},
}

SAMPLING_INTERVAL_MINUTES = 30
LAGS = [1, 2, 3]
TREND_WINDOWS_MINUTES = [10, 20, 30]
ROLLING_WINDOW = 6  # 6 * 30min = 3 hours


# ---------------------------------------------------------------------------
# Step 1-2: Load + validate schema
# ---------------------------------------------------------------------------

def load_dataset(path: Path = DATASET_PATH) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(
            f"Dataset not found at {path}. Place model_training_table.csv under Dataset/."
        )
    return pd.read_csv(path)


def validate_schema(df: pd.DataFrame) -> None:
    required = [TIMESTAMP_COL, GROWTH_STAGE_COL, *SENSOR_COLUMNS]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")


# ---------------------------------------------------------------------------
# Step 3-6: Parse timestamps, sort, dedupe, clean
# ---------------------------------------------------------------------------

def clean_dataset(df: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    report = {}

    df = df.copy()
    df[TIMESTAMP_COL] = pd.to_datetime(df[TIMESTAMP_COL])
    df = df.sort_values(TIMESTAMP_COL).reset_index(drop=True)

    before = len(df)
    df = df.drop_duplicates().reset_index(drop=True)
    report["duplicates_removed"] = before - len(df)

    before = len(df)
    df = df.dropna(subset=[*SENSOR_COLUMNS, GROWTH_STAGE_COL]).reset_index(drop=True)
    report["rows_dropped_missing_required"] = before - len(df)

    report["final_row_count"] = len(df)
    return df, report


# ---------------------------------------------------------------------------
# Step 7-8: Labels are already provided (risk_score_30m / 60m etc). We only
# validate them here - never regenerate from future rows a second time,
# which would risk introducing an inconsistency with the source data.
# ---------------------------------------------------------------------------

def validate_targets(df: pd.DataFrame) -> dict:
    report = {}
    for horizon, cols in TARGETS.items():
        score_col = cols["risk_score"]
        out_of_range = int((~df[score_col].between(0, 100)).sum())
        report[f"{horizon}min_out_of_range_scores"] = out_of_range
    return report


# ---------------------------------------------------------------------------
# Step 9-10: Feature engineering (lags, trends, rolling stats, time,
# categorical encoding). Every feature uses only data <= T (agent.md
# Section 8: never allow future information into the input features).
# ---------------------------------------------------------------------------

def build_features(df: pd.DataFrame, fitted_growth_stages: list[str] | None = None) -> tuple[pd.DataFrame, list[str]]:
    df = df.sort_values(TIMESTAMP_COL).reset_index(drop=True)
    # hour_decimal ships as a raw column in the training CSV but is never
    # provided by inference callers - always drop and recompute it below so
    # column order/presence is identical for training and inference.
    df = df.drop(columns=["hour_decimal"], errors="ignore")

    for col in SENSOR_COLUMNS:
        for lag in LAGS:
            df[f"{col}_lag_{lag}"] = df[col].shift(lag)

    for col in SENSOR_COLUMNS:
        for minutes in TREND_WINDOWS_MINUTES:
            steps = max(1, round(minutes / SAMPLING_INTERVAL_MINUTES))
            df[f"{col}_change_{minutes}min"] = df[col] - df[col].shift(steps)

    for col in SENSOR_COLUMNS:
        trailing = df[col].shift(1).rolling(window=ROLLING_WINDOW, min_periods=1)
        df[f"{col}_rolling_mean"] = trailing.mean()
        df[f"{col}_rolling_std"] = trailing.std()

    ts = df[TIMESTAMP_COL]
    df["hour"] = ts.dt.hour
    hour_fraction = ts.dt.hour + ts.dt.minute / 60.0
    # Always derive hour_decimal from the timestamp rather than trusting a
    # raw dataset column of the same name - callers building rows for
    # inference (app.py) don't supply it, so it must never be a passthrough.
    df["hour_decimal"] = hour_fraction
    df["cyclic_hour_sin"] = np.sin(2 * np.pi * hour_fraction / 24.0)
    df["cyclic_hour_cos"] = np.cos(2 * np.pi * hour_fraction / 24.0)

    categories = fitted_growth_stages or sorted(df[GROWTH_STAGE_COL].dropna().unique().tolist())
    df[GROWTH_STAGE_COL] = pd.Categorical(df[GROWTH_STAGE_COL], categories=categories)
    dummies = pd.get_dummies(df[GROWTH_STAGE_COL], prefix="growth_stage")
    df = pd.concat([df.drop(columns=[GROWTH_STAGE_COL]), dummies], axis=1)

    return df, categories


def engineered_feature_columns(df: pd.DataFrame) -> list[str]:
    target_columns = {c for cols in TARGETS.values() for c in cols.values()}
    exclude = target_columns | {TIMESTAMP_COL, SPLIT_COL, "label_origin"}
    return [c for c in df.columns if c not in exclude]


def drop_incomplete_history(df: pd.DataFrame, feature_columns: list[str]) -> pd.DataFrame:
    """Rows near the start of the series have NaN lag/rolling/trend
    features because there isn't enough history yet - drop rather than
    impute (agent.md Section 20)."""
    return df.dropna(subset=feature_columns).reset_index(drop=True)


# ---------------------------------------------------------------------------
# Step 11: Chronological split (dataset already ships a `split` column)
# ---------------------------------------------------------------------------

def split_dataset(df: pd.DataFrame) -> dict[str, pd.DataFrame]:
    mapping = {"Train": "train", "Validation": "validation", "Test": "test"}
    return {key: df[df[SPLIT_COL] == raw].copy() for raw, key in mapping.items() if (df[SPLIT_COL] == raw).any()}


# ---------------------------------------------------------------------------
# Step 12-14: Baseline + candidate models
# ---------------------------------------------------------------------------

def build_classifiers() -> dict:
    models = {
        "dummy_majority": DummyClassifier(strategy="most_frequent"),
        "logistic_regression": LogisticRegression(max_iter=1000, class_weight="balanced", random_state=RANDOM_SEED),
        "random_forest": RandomForestClassifier(n_estimators=300, class_weight="balanced", random_state=RANDOM_SEED),
    }
    if XGBClassifier is not None:
        models["xgboost"] = XGBClassifier(
            n_estimators=300, max_depth=4, learning_rate=0.05, eval_metric="logloss", random_state=RANDOM_SEED
        )
    return models


def build_regressors() -> dict:
    models = {
        "dummy_mean": DummyRegressor(strategy="mean"),
        "random_forest": RandomForestRegressor(n_estimators=300, random_state=RANDOM_SEED),
    }
    if XGBRegressor is not None:
        models["xgboost"] = XGBRegressor(
            n_estimators=300, max_depth=4, learning_rate=0.05, random_state=RANDOM_SEED
        )
    return models


def evaluate_classifier(model, X_test, y_test) -> dict:
    y_pred = model.predict(X_test)
    return {
        "classification_report": classification_report(y_test, y_pred, zero_division=0, output_dict=True),
        "confusion_matrix": confusion_matrix(y_test, y_pred).tolist(),
    }


def evaluate_regressor(model, X_test, y_test) -> dict:
    y_pred = model.predict(X_test)
    return {"mean_absolute_error": float(mean_absolute_error(y_test, y_pred))}


# ---------------------------------------------------------------------------
# Step 21: Save artifacts
# ---------------------------------------------------------------------------

def save_artifacts(models_by_target: dict, growth_stage_categories: list[str], feature_columns: list[str], metrics: dict) -> None:
    MODEL_DIR.mkdir(exist_ok=True)

    for (horizon, target_kind), model in models_by_target.items():
        joblib.dump(model, MODEL_DIR / f"{target_kind}_{horizon}min_model.pkl")

    joblib.dump({GROWTH_STAGE_COL: growth_stage_categories}, MODEL_DIR / "encoders.pkl")

    metadata = {
        "model_version": "environmental-stress-v2",
        "training_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "features": feature_columns,
        "targets": TARGETS,
        "dataset_version": "model_training_table.csv (developer package, synthetic/derived labels)",
        "metrics": metrics,
        "model_type": "RandomForest/XGBoost classifiers (stress_type, risk_level) + regressors (risk_score) per horizon",
    }
    (MODEL_DIR / "model_metadata.json").write_text(json.dumps(metadata, indent=2, default=str))


# ---------------------------------------------------------------------------
# Orchestration - NOT executed on import
# ---------------------------------------------------------------------------

def run() -> None:
    df = load_dataset()
    validate_schema(df)

    df, cleaning_report = clean_dataset(df)
    print("Cleaning report:", cleaning_report)

    target_report = validate_targets(df)
    print("Target validation report:", target_report)

    engineered, growth_stage_categories = build_features(df)
    feature_columns = engineered_feature_columns(engineered)
    engineered = drop_incomplete_history(engineered, feature_columns)

    splits = split_dataset(engineered)
    print("Split sizes:", {k: len(v) for k, v in splits.items()})

    trained_models = {}
    all_metrics = {}

    classification_targets = ["stress_type", "risk_level"]
    regression_targets = ["risk_score"]

    for horizon, cols in TARGETS.items():
        for target_kind in classification_targets:
            target_col = cols[target_kind]
            X_train, y_train = splits["train"][feature_columns], splits["train"][target_col]
            X_test, y_test = splits["test"][feature_columns], splits["test"][target_col]

            candidates = build_classifiers()
            best_name, best_model, best_score = None, None, -1.0

            for name, model in candidates.items():
                model.fit(X_train, y_train)
                metrics = evaluate_classifier(model, X_test, y_test)
                f1_macro = metrics["classification_report"]["macro avg"]["f1-score"]
                print(f"[{horizon}min:{target_kind}] {name}: macro F1 = {f1_macro:.3f}")
                if name != "dummy_majority" and f1_macro > best_score:
                    best_name, best_model, best_score = name, model, f1_macro
                all_metrics[f"{horizon}min_{target_kind}_{name}"] = metrics

            trained_models[(horizon, target_kind)] = best_model
            print(f"[{horizon}min:{target_kind}] selected model: {best_name} (macro F1 = {best_score:.3f})")

        for target_kind in regression_targets:
            target_col = cols[target_kind]
            X_train, y_train = splits["train"][feature_columns], splits["train"][target_col]
            X_test, y_test = splits["test"][feature_columns], splits["test"][target_col]

            candidates = build_regressors()
            best_name, best_model, best_score = None, None, float("inf")

            for name, model in candidates.items():
                model.fit(X_train, y_train)
                metrics = evaluate_regressor(model, X_test, y_test)
                mae = metrics["mean_absolute_error"]
                print(f"[{horizon}min:{target_kind}] {name}: MAE = {mae:.3f}")
                if name != "dummy_mean" and mae < best_score:
                    best_name, best_model, best_score = name, model, mae
                all_metrics[f"{horizon}min_{target_kind}_{name}"] = metrics

            trained_models[(horizon, target_kind)] = best_model
            print(f"[{horizon}min:{target_kind}] selected model: {best_name} (MAE = {best_score:.3f})")

    save_artifacts(trained_models, growth_stage_categories, feature_columns, all_metrics)
    print(f"Artifacts saved to {MODEL_DIR}")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python train.py
    run()
