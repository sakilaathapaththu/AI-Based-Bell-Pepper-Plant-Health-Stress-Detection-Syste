from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

from app.services import adaptive_service

router = APIRouter(prefix="/adaptive", tags=["adaptive"])


class RecoveryPlanRequest(BaseModel):
    plant_id: str | None = None
    rgb_result: dict | None = None
    thermal_result: dict | None = None
    environmental_result: dict | None = None


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.post("/generate-recovery-plan")
def generate_recovery_plan(request: RecoveryPlanRequest) -> dict:
    return adaptive_service.generate_recovery_plan(
        plant_id=request.plant_id,
        rgb_result=request.rgb_result,
        thermal_result=request.thermal_result,
        environmental_result=request.environmental_result,
    )
