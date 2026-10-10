from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.services import environmental_service

router = APIRouter(prefix="/environmental", tags=["environmental"])


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
    historical_context: list[HistoricalReading] | None = Field(default=None)


@router.get("/health")
def health() -> dict:
    return {"artifacts_loaded": environmental_service.artifacts_ready()}


@router.post("/check-environment")
def check_environment(request: CurrentEnvironment) -> dict:
    current_environment = request.model_dump(exclude={"timestamp", "growth_stage"})
    try:
        return environmental_service.check_environment(request.timestamp, request.growth_stage, current_environment)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/predict")
def predict(request: PredictRequest) -> dict:
    historical_context = [r.model_dump() for r in request.historical_context] if request.historical_context else None
    try:
        return environmental_service.predict(
            timestamp=request.timestamp,
            growth_stage=request.growth_stage,
            air_temperature_c=request.air_temperature_c,
            relative_humidity_pct=request.relative_humidity_pct,
            light_intensity_lux=request.light_intensity_lux,
            soil_temperature_c=request.soil_temperature_c,
            historical_context=historical_context,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
