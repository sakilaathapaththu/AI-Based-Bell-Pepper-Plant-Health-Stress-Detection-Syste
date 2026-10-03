"""
Orchestrates fusion.py (combine the 3 upstream components' outputs) and
knowledge_base.py (apply the 5 deterministic rules) into one structured
recovery-plan decision - the full "what should the farmer do, and why"
answer, BEFORE the Gemini explanation layer (explanation.py) rephrases it
for display.

Nothing in this file executes on import.
"""

from __future__ import annotations

import fusion
import knowledge_base


def generate_recovery_plan(
    plant_id: str | None = None,
    rgb_result: dict | None = None,
    thermal_result: dict | None = None,
    environmental_result: dict | None = None,
) -> dict:
    """rgb_result/thermal_result/environmental_result are expected to be
    the exact JSON response bodies already returned by each component's own
    /predict endpoint - see fusion.py's module docstring for the expected
    shape of each. Any of the three may be omitted."""
    fused = fusion.fuse_inputs(rgb_result, thermal_result, environmental_result)

    decision = knowledge_base.apply_rules(
        flags=fused["flags"],
        severities=fused["severities"],
        growth_stage=fused["growth_stage"],
        environmental_stress_class=fused["environmental_stress_class"],
        risk_60m_level=fused["risk_60m_level"],
    )

    return {
        "plant_id": plant_id,
        **decision,
        "environmental_context": fused["environmental_stress_class"],
        "growth_stage": fused["growth_stage"],
        "possible_environmental_confound": fused["possible_environmental_confound"],
        "supporting_evidence": fused["evidence"],
        "inputs_received": {
            "rgb": rgb_result is not None,
            "thermal": thermal_result is not None,
            "environmental": environmental_result is not None,
        },
    }
