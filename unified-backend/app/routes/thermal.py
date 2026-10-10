from __future__ import annotations

import json

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.services import thermal_service

router = APIRouter(prefix="/thermal", tags=["thermal"])


@router.get("/health")
def health() -> dict:
    return {
        "artifacts_loaded": thermal_service.artifacts_ready(),
        "model_version": thermal_service.Artifacts.metadata.get("model_version") if thermal_service.Artifacts.metadata else None,
    }


@router.post("/predict")
async def predict(thermal_image: UploadFile = File(...), plant_id: str | None = Form(None)) -> dict:
    image_bytes = await thermal_image.read()
    try:
        return thermal_service.predict(image_bytes, plant_id=plant_id)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=json.loads(str(exc))) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
