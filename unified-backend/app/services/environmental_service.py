"""
Environmental stress-prediction inference service.

Ported from environmental-stress-prediction/app.py + train.py (build_features)
+ environmental_reference.py + replay_lookup.py.
"""

from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

MODEL_DIR = Path(__file__).resolve().parent.parent / "models" / "environmental"
DATA_DIR = Path(__file__).resolve().parent.parent / "data"

REFERENCE_RANGES_PATH = DATA_DIR / "bell_pepper_reference_ranges.csv"
REPLAY_SOURCE_PATH = DATA_DIR / "model_training_table.csv"

TIMESTAMP_COL = "timestamp"
GROWTH_STAGE_COL = "growth_stage"
SENSOR_COLUMNS = ["air_temperature_c", "relative_humidity_pct", "light_intensity_lux", "soil_temperature_c"]

SAMPLING_INTERVAL_MINUTES = 30
LAGS = [1, 2, 3]
TREND_WINDOWS_MINUTES = [10, 20, 30]
ROLLING_WINDOW = 6

DAY_START_HOUR = 6
DAY_END_HOUR = 18
SLIGHT_BAND_FRACTION = 0.15

DATA_SOURCE_MODE = "Virtual Sensor / Dataset Replay"

HISTORY_COLUMNS = [TIMESTAMP_COL, GROWTH_STAGE_COL, *SENSOR_COLUMNS]

_replay_cache: pd.DataFrame | None = None


class Artifacts:
    stress_type_30m = None
    stress_type_60m = None
    risk_level_30m = None
    risk_level_60m = None
    risk_score_30m = None
    risk_score_60m = None
    encoders = None
    metadata = None
    reference_ranges = None


def load_reference_ranges() -> pd.DataFrame:
    return pd.read_csv(REFERENCE_RANGES_PATH).set_index("growth_stage")


def load_artifacts() -> None:
    required = [
        MODEL_DIR / "stress_type_30min_model.pkl",
        MODEL_DIR / "stress_type_60min_model.pkl",
        MODEL_DIR / "risk_level_30min_model.pkl",
        MODEL_DIR / "risk_level_60min_model.pkl",
        MODEL_DIR / "risk_score_30min_model.pkl",
        MODEL_DIR / "risk_score_60min_model.pkl",
        MODEL_DIR / "encoders.pkl",
        MODEL_DIR / "model_metadata.json",
    ]
    missing = [p for p in required if not p.exists()]
    if missing:
        Artifacts.reference_ranges = load_reference_ranges()
        return

    Artifacts.stress_type_30m = joblib.load(MODEL_DIR / "stress_type_30min_model.pkl")
    Artifacts.stress_type_60m = joblib.load(MODEL_DIR / "stress_type_60min_model.pkl")
    Artifacts.risk_level_30m = joblib.load(MODEL_DIR / "risk_level_30min_model.pkl")
    Artifacts.risk_level_60m = joblib.load(MODEL_DIR / "risk_level_60min_model.pkl")
    Artifacts.risk_score_30m = joblib.load(MODEL_DIR / "risk_score_30min_model.pkl")
    Artifacts.risk_score_60m = joblib.load(MODEL_DIR / "risk_score_60min_model.pkl")
    Artifacts.encoders = joblib.load(MODEL_DIR / "encoders.pkl")
    Artifacts.metadata = json.loads((MODEL_DIR / "model_metadata.json").read_text())
    Artifacts.reference_ranges = load_reference_ranges()


def artifacts_ready() -> bool:
    return Artifacts.stress_type_30m is not None


def is_daytime(hour: int) -> bool:
    return DAY_START_HOUR <= hour < DAY_END_HOUR


def _status(value: float, low: float, high: float) -> str:
    span = high - low
    slight = span * SLIGHT_BAND_FRACTION
    if value < low - slight:
        return "Low"
    if value < low:
        return "Slightly Low"
    if value > high + slight:
        return "High"
    if value > high:
        return "Slightly High"
    return "Normal"


def _direction_text(field: str, status: str) -> str | None:
    label = {
        "air_temperature_c": "temperature",
        "relative_humidity_pct": "humidity",
        "soil_temperature_c": "soil temperature",
        "light_intensity_lux": "light",
    }[field]
    if status in ("High", "Slightly High"):
        return f"Reduce {label} towards the suitable range"
    if status in ("Low", "Slightly Low"):
        return f"Increase {label} towards the suitable range"
    return None


def evaluate_current_environment(current_environment: dict, growth_stage: str, hour: int, ranges: pd.DataFrame) -> dict:
    if growth_stage not in ranges.index:
        raise ValueError(f"Unknown growth_stage: {growth_stage}")
    row = ranges.loc[growth_stage]
    daytime = is_daytime(hour)

    temp_low, temp_high = (
        (float(row["day_air_temp_min_c"]), float(row["day_air_temp_max_c"]))
        if daytime
        else (float(row["night_air_temp_min_c"]), float(row["night_air_temp_max_c"]))
    )

    results = {}

    air_temp = current_environment["air_temperature_c"]
    results["air_temperature_c"] = {
        "value": air_temp, "status": _status(air_temp, temp_low, temp_high), "suitable_range": [temp_low, temp_high],
    }

    humidity = current_environment["relative_humidity_pct"]
    rh_low, rh_high = float(row["rh_min_pct"]), float(row["rh_max_pct"])
    results["relative_humidity_pct"] = {
        "value": humidity, "status": _status(humidity, rh_low, rh_high), "suitable_range": [rh_low, rh_high],
    }

    soil_temp = current_environment["soil_temperature_c"]
    soil_low, soil_high = float(row["soil_temp_min_c"]), float(row["soil_temp_max_c"])
    results["soil_temperature_c"] = {
        "value": soil_temp, "status": _status(soil_temp, soil_low, soil_high), "suitable_range": [soil_low, soil_high],
    }

    light = current_environment["light_intensity_lux"]
    if daytime:
        light_low, light_high = float(row["day_light_min_lux_prototype"]), float(row["day_light_max_lux_prototype"])
        light_status = _status(light, light_low, light_high)
        light_range = [light_low, light_high]
    else:
        light_status = "Normal"
        light_range = None
    results["light_intensity_lux"] = {"value": light, "status": light_status, "suitable_range": light_range}

    for field, info in results.items():
        info["adjustment_direction"] = _direction_text(field, info["status"])

    return results


def main_contributing_factors(environment_status: dict) -> list[str]:
    label = {
        "air_temperature_c": "Air Temperature",
        "relative_humidity_pct": "Relative Humidity",
        "soil_temperature_c": "Soil Temperature",
        "light_intensity_lux": "Light Intensity",
    }
    severity_rank = {"High": 0, "Low": 0, "Slightly High": 1, "Slightly Low": 1, "Normal": 2}
    factors = [
        (severity_rank[info["status"]], f"{info['status']} {label[field]}")
        for field, info in environment_status.items()
        if info["status"] != "Normal"
    ]
    factors.sort(key=lambda x: x[0])
    return [text for _, text in factors]


def _load_replay_source() -> pd.DataFrame:
    global _replay_cache
    if _replay_cache is None:
        df = pd.read_csv(REPLAY_SOURCE_PATH, usecols=HISTORY_COLUMNS)
        df[TIMESTAMP_COL] = pd.to_datetime(df[TIMESTAMP_COL])
        df = df.sort_values(TIMESTAMP_COL).reset_index(drop=True)
        df["_minute_of_day"] = df[TIMESTAMP_COL].dt.hour * 60 + df[TIMESTAMP_COL].dt.minute
        _replay_cache = df
    return _replay_cache


def get_historical_context(growth_stage: str, hour: int, minute: int, window: int = 6) -> list[dict]:
    df = _load_replay_source()
    stage_df = df[df[GROWTH_STAGE_COL] == growth_stage].reset_index(drop=True)
    if stage_df.empty:
        raise ValueError(f"No replay history available for growth_stage: {growth_stage}")

    target_minute = hour * 60 + minute
    closest_idx = (stage_df["_minute_of_day"] - target_minute).abs().idxmin()

    start = max(0, closest_idx - window + 1)
    end = closest_idx + 1
    if end - start < window:
        end = min(len(stage_df), start + window)

    history = stage_df.iloc[start:end][HISTORY_COLUMNS].copy()
    history[TIMESTAMP_COL] = history[TIMESTAMP_COL].astype(str)
    return history.to_dict(orient="records")


def build_features(df: pd.DataFrame, fitted_growth_stages: list[str] | None = None) -> tuple[pd.DataFrame, list[str]]:
    df = df.sort_values(TIMESTAMP_COL).reset_index(drop=True)
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
    df["hour_decimal"] = hour_fraction
    df["cyclic_hour_sin"] = np.sin(2 * np.pi * hour_fraction / 24.0)
    df["cyclic_hour_cos"] = np.cos(2 * np.pi * hour_fraction / 24.0)

    categories = fitted_growth_stages or sorted(df[GROWTH_STAGE_COL].dropna().unique().tolist())
    df[GROWTH_STAGE_COL] = pd.Categorical(df[GROWTH_STAGE_COL], categories=categories)
    dummies = pd.get_dummies(df[GROWTH_STAGE_COL], prefix="growth_stage")
    df = pd.concat([df.drop(columns=[GROWTH_STAGE_COL]), dummies], axis=1)

    return df, categories


def check_environment(timestamp: str, growth_stage: str, current_environment: dict) -> dict:
    hour = pd.to_datetime(timestamp).hour
    status = evaluate_current_environment(current_environment, growth_stage, hour, Artifacts.reference_ranges)
    return {
        "timestamp": timestamp,
        "growth_stage": growth_stage,
        "environment_status": status,
        "data_source_mode": DATA_SOURCE_MODE,
    }


def predict(
    timestamp: str,
    growth_stage: str,
    air_temperature_c: float,
    relative_humidity_pct: float,
    light_intensity_lux: float,
    soil_temperature_c: float,
    historical_context: list[dict] | None = None,
) -> dict:
    if not artifacts_ready():
        raise RuntimeError("Environmental model artifacts not loaded. Check app/models/environmental/.")

    current_environment = {
        "air_temperature_c": air_temperature_c,
        "relative_humidity_pct": relative_humidity_pct,
        "light_intensity_lux": light_intensity_lux,
        "soil_temperature_c": soil_temperature_c,
    }
    now_timestamp = pd.to_datetime(timestamp)

    if historical_context:
        history_records = historical_context
    else:
        history_records = get_historical_context(growth_stage, now_timestamp.hour, now_timestamp.minute)

    history_df = pd.DataFrame(history_records)
    history_df[TIMESTAMP_COL] = pd.to_datetime(history_df[TIMESTAMP_COL])

    now_row = {**current_environment, GROWTH_STAGE_COL: growth_stage, TIMESTAMP_COL: now_timestamp}
    full_history = pd.concat([history_df, pd.DataFrame([now_row])], ignore_index=True)

    engineered, _ = build_features(full_history, fitted_growth_stages=Artifacts.encoders[GROWTH_STAGE_COL])
    feature_columns = Artifacts.metadata["features"]
    missing_features = [c for c in feature_columns if c not in engineered.columns]
    if missing_features:
        raise ValueError(f"Insufficient historical_context to compute required features: {missing_features}")
    current_features = engineered.iloc[[-1]][feature_columns]

    if current_features.isna().any(axis=1).iloc[0]:
        raise ValueError("Insufficient historical_context to compute all required lag/rolling features")

    stress_type_30 = str(Artifacts.stress_type_30m.predict(current_features)[0])
    stress_type_60 = str(Artifacts.stress_type_60m.predict(current_features)[0])
    level_30 = str(Artifacts.risk_level_30m.predict(current_features)[0])
    level_60 = str(Artifacts.risk_level_60m.predict(current_features)[0])
    score_30 = float(Artifacts.risk_score_30m.predict(current_features)[0])
    score_60 = float(Artifacts.risk_score_60m.predict(current_features)[0])

    environment_status = evaluate_current_environment(current_environment, growth_stage, now_timestamp.hour, Artifacts.reference_ranges)
    contributing_factors = main_contributing_factors(environment_status)

    predicted_stress_type = stress_type_60 if level_60 != "Low" else stress_type_30
    explanation = (
        f"Current environmental conditions indicate {predicted_stress_type.lower()} risk, "
        f"primarily driven by: {', '.join(contributing_factors)}."
        if contributing_factors
        else f"Current environmental conditions are broadly within suitable ranges for {predicted_stress_type.lower()}."
    )

    return {
        "prediction_timestamp": now_timestamp.isoformat(),
        "growth_stage": growth_stage,
        "current_environment": current_environment,
        "stress_type": predicted_stress_type,
        "risk_30m": {"level": level_30, "score": round(score_30, 1)},
        "risk_60m": {"level": level_60, "score": round(score_60, 1)},
        "main_contributing_factors": contributing_factors,
        "explanation": explanation,
        "data_source_mode": DATA_SOURCE_MODE,
        "model_version": Artifacts.metadata.get("model_version") if Artifacts.metadata else None,
        "disclaimer": "Model trained on derived/synthetic prototype labels - not observed plant-stress ground truth.",
        "recovery_handoff": {
            "stress_type": predicted_stress_type,
            "risk_30m": {"level": level_30, "score": round(score_30, 1)},
            "risk_60m": {"level": level_60, "score": round(score_60, 1)},
            "growth_stage": growth_stage,
            "current_environment": current_environment,
            "main_contributing_factors": contributing_factors,
        },
    }
