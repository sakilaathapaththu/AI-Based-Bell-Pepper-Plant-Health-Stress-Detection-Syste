from __future__ import annotations

import json

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.services import rgb_service

router = APIRouter(prefix="/rgb", tags=["rgb"])


@router.get("/health")
def health() -> dict:
    return {
        "artifacts_loaded": rgb_service.artifacts_ready(),
        "model_version": rgb_service.Artifacts.metadata.get("model_version") if rgb_service.Artifacts.metadata else None,
    }


@router.post("/predict")
async def predict(image: UploadFile = File(...)) -> dict:
    image_bytes = await image.read()
    try:
        return rgb_service.predict(image_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=json.loads(str(exc))) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
