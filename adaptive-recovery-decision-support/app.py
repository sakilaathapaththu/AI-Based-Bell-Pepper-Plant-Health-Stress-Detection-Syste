"""
Adaptive Recovery Decision Support System (Component 4) - FastAPI service.

Receives the outputs already produced by the other three components (RGB,
Thermal, Environmental), fuses them (fusion.py), applies the deterministic
recovery-decision rules (knowledge_base.py), and returns a final recovery
plan the mobile app can show to the farmer: Recommended Action, Priority,
Why This Action, and Supporting Evidence - exactly the four fields
described for this component's output screen.

This component makes no classification/prediction itself - all stress
detection already happened upstream. Its only "model" is the Gemini-based
explanation layer (explanation.py), which only rephrases an
already-decided answer, never decides it.

Run with:
    uvicorn app:app --reload --port 8002
"""

from __future__ import annotations

from fastapi import FastAPI
from pydantic import BaseModel

import decision_engine
import explanation

app = FastAPI(title="Adaptive Recovery Decision Support System (Component 4) API")


class RecoveryPlanRequest(BaseModel):
    plant_id: str | None = None
    # Each of these is expected to be the raw JSON response body already
    # returned by that component's own /predict endpoint - see
    # fusion.py's module docstring for the exact expected shape of each.
    rgb_result: dict | None = None
    thermal_result: dict | None = None
    environmental_result: dict | None = None


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/generate-recovery-plan")
def generate_recovery_plan(request: RecoveryPlanRequest) -> dict:
    decision = decision_engine.generate_recovery_plan(
        plant_id=request.plant_id,
        rgb_result=request.rgb_result,
        thermal_result=request.thermal_result,
        environmental_result=request.environmental_result,
    )

    farmer_explanation = explanation.generate_farmer_explanation(decision)

    return {
        "plant_id": decision["plant_id"],
        "recommended_action": decision["recommended_action"],
        "priority": decision["priority"],
        "why_this_action": farmer_explanation["text"],
        "why_this_action_source": farmer_explanation["source"],
        "supporting_evidence": decision["supporting_evidence"],
        "details": {
            "primary_problem": decision["primary_problem"],
            "severity": decision["severity"],
            "secondary_action": decision["secondary_action"],
            "environmental_context": decision["environmental_context"],
            "growth_stage": decision["growth_stage"],
            "possible_environmental_confound": decision["possible_environmental_confound"],
            "agronomic_evidence_status": decision["agronomic_evidence_status"],
            "inputs_received": decision["inputs_received"],
        },
    }


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   uvicorn app:app --reload --port 8002
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8002)
