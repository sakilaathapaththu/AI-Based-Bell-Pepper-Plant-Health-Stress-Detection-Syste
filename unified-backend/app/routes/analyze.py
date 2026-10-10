"""
Combined flow: one call that runs RGB + Thermal + Environmental (whichever
inputs are supplied) and feeds all three results into the Adaptive Recovery
rule engine to produce the final recovery plan.
"""

from __future__ import annotations

from fastapi import APIRouter, File, Form, UploadFile

from app.services import adaptive_service, environmental_service, rgb_service, thermal_service

router = APIRouter(tags=["analyze"])


@router.post("/analyze")
async def analyze(
    plant_id: str | None = Form(None),
    rgb_image: UploadFile | None = File(None),
    thermal_image: UploadFile | None = File(None),
    timestamp: str | None = Form(None),
    growth_stage: str | None = Form(None),
    air_temperature_c: float | None = Form(None),
    relative_humidity_pct: float | None = Form(None),
    light_intensity_lux: float | None = Form(None),
    soil_temperature_c: float | None = Form(None),
) -> dict:
    results: dict = {}

    if rgb_image is not None:
        content = await rgb_image.read()
        try:
            results["rgb"] = rgb_service.predict(content)
        except (ValueError, RuntimeError) as exc:
            results["rgb"] = {"error": str(exc)}

    if thermal_image is not None:
        content = await thermal_image.read()
        try:
            results["thermal"] = thermal_service.predict(content, plant_id=plant_id)
        except (ValueError, RuntimeError) as exc:
            results["thermal"] = {"error": str(exc)}

    if timestamp and growth_stage and air_temperature_c is not None:
        try:
            results["environmental"] = environmental_service.predict(
                timestamp=timestamp,
                growth_stage=growth_stage,
                air_temperature_c=air_temperature_c,
                relative_humidity_pct=relative_humidity_pct,
                light_intensity_lux=light_intensity_lux,
                soil_temperature_c=soil_temperature_c,
            )
        except (ValueError, RuntimeError) as exc:
            results["environmental"] = {"error": str(exc)}

    def clean(name: str) -> dict | None:
        value = results.get(name)
        return None if value is None or "error" in value else value

    recovery_plan = adaptive_service.generate_recovery_plan(
        plant_id=plant_id,
        rgb_result=clean("rgb"),
        thermal_result=clean("thermal"),
        environmental_result=clean("environmental"),
    )

    return {
        "plant_id": plant_id,
        "component_results": results,
        "recovery_plan": recovery_plan,
    }
