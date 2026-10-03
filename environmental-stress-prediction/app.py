"""
Environmental Stress Prediction - FastAPI inference service.

Loads the artifacts produced by train.py (model/{stress_type,risk_level,
risk_score}_{30,60}min_model.pkl, model/encoders.pkl, model/model_metadata.json)
and serves two endpoints:

- POST /check-environment  - rule-based comparison of current readings against
  suitable ranges (Section: "Check Current Environment" in the UI flow).
  Gives High/Low/Normal status and adjustment direction only - never an
  exact recovery action (that belongs to the Recovery DSS).
- POST /predict            - takes only the single current reading (same
  shape as /check-environment) and forecasts stress_type / risk_level /
  risk_score at +30min and +60min, matching Dataset/model_output_format.json.
  Prior readings needed for lag/rolling features are auto-filled from the
  Virtual Sensor / Dataset Replay (replay_lookup.py) - the caller never
  re-enters or resends historical values.

Uses the exact same feature-engineering functions as train.py (agent.md
Section 27: never recreate preprocessing manually inside the API).

Run with:
    uvicorn app:app --reload

Requires model/ to already contain trained artifacts (run train.py first).
"""

from __future__ import annotations

import json
from contextlib import asynccontextmanager

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from environmental_reference import (
    evaluate_current_environment,
    load_reference_ranges,
    main_contributing_factors,
)
from replay_lookup import get_historical_context
from train import (
    GROWTH_STAGE_COL,
    MODEL_DIR,
    SENSOR_COLUMNS,
    TIMESTAMP_COL,
    build_features,
)

DATA_SOURCE_MODE = "Virtual Sensor / Dataset Replay"


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_artifacts()
    yield


app = FastAPI(title="Environmental Stress Prediction API", lifespan=lifespan)


class HistoricalReading(BaseModel):
    timestamp: str
    growth_stage: str
    air_temperature_c: float
    relative_humidity_pct: float
    light_intensity_lux: float
    soil_temperature_c: float


class CurrentEnvironment(BaseModel):
    timestamp: str
    growth_stage: str
    air_temperature_c: float
    relative_humidity_pct: float
    light_intensity_lux: float
    soil_temperature_c: float


class PredictRequest(BaseModel):
    timestamp: str
    growth_stage: str
    air_temperature_c: float
    relative_humidity_pct: float
    light_intensity_lux: float
    soil_temperature_c: float
    historical_context: list[HistoricalReading] | None = Field(
        default=None,
        description=(
            "Optional explicit prior readings. Normally omitted - the user "
            "never re-enters values; history is auto-filled from the "
            "Virtual Sensor / Dataset Replay by growth stage + time-of-day."
        ),
    )


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
        # Do not crash the app at import time - allow /health to report the
        # problem instead of every startup failing during development.
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


@app.get("/health")
def health() -> dict:
    return {"artifacts_loaded": Artifacts.stress_type_30m is not None}


@app.post("/check-environment")
def check_environment(request: CurrentEnvironment) -> dict:
    """Rule-based comparison against suitable ranges - no ML model involved.
    This is the "Check Current Environment" step in the UI flow."""
    hour = pd.to_datetime(request.timestamp).hour
    current_environment = request.model_dump(exclude={"timestamp", "growth_stage"})

    try:
        status = evaluate_current_environment(
            current_environment, request.growth_stage, hour, Artifacts.reference_ranges
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return {
        "timestamp": request.timestamp,
        "growth_stage": request.growth_stage,
        "environment_status": status,
        "data_source_mode": DATA_SOURCE_MODE,
    }


@app.post("/predict")
def predict(request: PredictRequest) -> dict:
    if Artifacts.stress_type_30m is None:
        raise HTTPException(
            status_code=503,
            detail="Model artifacts not found under model/. Run train.py first.",
        )

    current_environment = {
        "air_temperature_c": request.air_temperature_c,
        "relative_humidity_pct": request.relative_humidity_pct,
        "light_intensity_lux": request.light_intensity_lux,
        "soil_temperature_c": request.soil_temperature_c,
    }
    now_timestamp = pd.to_datetime(request.timestamp)

    if request.historical_context:
        history_records = [r.model_dump() for r in request.historical_context]
    else:
        # User never re-enters values - auto-fill prior readings from the
        # Virtual Sensor / Dataset Replay, matched by growth stage + time-of-day.
        try:
            history_records = get_historical_context(
                request.growth_stage, now_timestamp.hour, now_timestamp.minute
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    history_df = pd.DataFrame(history_records)
    history_df[TIMESTAMP_COL] = pd.to_datetime(history_df[TIMESTAMP_COL])

    now_row = {**current_environment, GROWTH_STAGE_COL: request.growth_stage, TIMESTAMP_COL: now_timestamp}
    full_history = pd.concat([history_df, pd.DataFrame([now_row])], ignore_index=True)

    engineered, _ = build_features(full_history, fitted_growth_stages=Artifacts.encoders[GROWTH_STAGE_COL])
    # Use the exact column order captured at training time (model_metadata.json)
    # rather than recomputing it from this request's dataframe - column order
    # must match what each model was fit on, and a fresh inference frame can
    # order/omit columns differently than the training frame did.
    feature_columns = Artifacts.metadata["features"]
    missing_features = [c for c in feature_columns if c not in engineered.columns]
    if missing_features:
        raise HTTPException(
            status_code=422,
            detail=f"Insufficient historical_context to compute required features: {missing_features}",
        )
    current_features = engineered.iloc[[-1]][feature_columns]

    if current_features.isna().any(axis=1).iloc[0]:
        raise HTTPException(
            status_code=422,
            detail="Insufficient historical_context to compute all required lag/rolling features",
        )

    stress_type_30 = str(Artifacts.stress_type_30m.predict(current_features)[0])
    stress_type_60 = str(Artifacts.stress_type_60m.predict(current_features)[0])
    level_30 = str(Artifacts.risk_level_30m.predict(current_features)[0])
    level_60 = str(Artifacts.risk_level_60m.predict(current_features)[0])
    score_30 = float(Artifacts.risk_score_30m.predict(current_features)[0])
    score_60 = float(Artifacts.risk_score_60m.predict(current_features)[0])

    # Explain the *current* reading against reference ranges - these are the
    # environmental signals feeding the forecast, shown to the user as
    # "Main Contributing Factors".
    environment_status = evaluate_current_environment(
        current_environment, request.growth_stage, now_timestamp.hour, Artifacts.reference_ranges
    )
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
        "growth_stage": request.growth_stage,
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
            "growth_stage": request.growth_stage,
            "current_environment": current_environment,
            "main_contributing_factors": contributing_factors,
        },
    }
