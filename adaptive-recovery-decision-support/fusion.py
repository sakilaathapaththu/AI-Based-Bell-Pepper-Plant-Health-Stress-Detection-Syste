"""
Multimodal fusion: translates the raw JSON payloads from the three upstream
components into the flags/severities/environmental-context representation
that knowledge_base.py's rule functions operate on.

Expected upstream payload shapes (as actually returned by each component's
/predict endpoint - see each component's app.py):

RGB (rgb-stress-detection/app.py):
    {"plant_condition": "Healthy"|"Stressed",
     "stress_type": "Water_Deficit"|"Nutrient_Deficiency"|"Aphid"|"Thrips"|None,
     "severity": "Mild"|"Moderate"|"Severe"|None, "confidence": float, ...}

Thermal (Thermal-stress-evidence-identify/app.py):
    {"stress_status": "Healthy"|"Stressed",
     "stress_type": "Heat_Stress"|"Nutrient_Stress"|"Water_Stress"|None,
     "severity": "Mild"|"Moderate"|"Severe"|None, "model_confidence": float,
     "possible_environmental_confound": bool, ...}

Environmental (environmental-stress-prediction/app.py):
    {"stress_type": "Heat Stress"|"Cold Stress"|... (one of the 10 classes
     in dataset_all/.../stress_label_definitions.csv), "growth_stage": str,
     "risk_30m": {...}, "risk_60m": {...}, ...}

Any of the three inputs may be omitted (None) - a partial recovery plan can
still be produced from whichever components actually ran, which matters in
practice since not every component may complete in time for every request.

Nothing in this file executes on import.
"""

from __future__ import annotations

import config


def _severity_rank_max(current: str | None, candidate: str) -> str:
    if current is None:
        return candidate
    return candidate if config.SEVERITY_RANK[candidate] > config.SEVERITY_RANK[current] else current


def _normalize_rgb(rgb_payload: dict | None) -> dict | None:
    """Returns one evidence item {problem, severity, source, confidence},
    or None if there's no RGB evidence (missing, or plant_condition is
    Healthy)."""
    if not rgb_payload or rgb_payload.get("plant_condition") != "Stressed":
        return None

    problem = rgb_payload.get("stress_type")
    if problem not in config.PRIORITY_ORDER:
        # Defensive: RGB's class list may differ from this component's
        # taxonomy if either side changes independently - skip rather than
        # crash, since a fusion input mismatch should degrade gracefully,
        # not take down the whole recovery-plan request.
        return None

    severity = config.SEVERITY_LEVEL_MAP.get(rgb_payload.get("severity"), config.DEFAULT_SEVERITY_IF_UNSPECIFIED)
    return {"problem": problem, "severity": severity, "source": "RGB", "confidence": rgb_payload.get("confidence")}


def _normalize_thermal(thermal_payload: dict | None) -> tuple[dict | None, bool, bool]:
    """Returns (evidence_item_or_None, heat_signal_detected, possible_environmental_confound)."""
    if not thermal_payload or thermal_payload.get("stress_status") != "Stressed":
        return None, False, False

    thermal_class = thermal_payload.get("stress_type")
    confound = bool(thermal_payload.get("possible_environmental_confound", False))

    if thermal_class == config.THERMAL_HEAT_CLASS:
        # Heat_Stress has no Primary_Problem slot in this taxonomy - it
        # only contributes an environmental-context signal (see config.py).
        return None, True, confound

    problem = config.THERMAL_CLASS_TO_PROBLEM.get(thermal_class)
    if problem is None:
        return None, False, confound

    severity = config.SEVERITY_LEVEL_MAP.get(
        thermal_payload.get("severity"), config.DEFAULT_SEVERITY_IF_UNSPECIFIED
    )
    evidence = {
        "problem": problem,
        "severity": severity,
        "source": "Thermal",
        "confidence": thermal_payload.get("model_confidence"),
    }
    return evidence, False, confound


def _normalize_environmental(environmental_payload: dict | None) -> tuple[str, str, str | None]:
    """Returns (environmental_stress_class, growth_stage, risk_60m_level).

    risk_60m_level feeds ONLY the Rule 4b priority-escalation enhancement
    (see knowledge_base.escalate_priority_for_forecast_risk) - it is not
    part of the reverse-engineered reference-dataset rules."""
    if not environmental_payload:
        return config.DEFAULT_ENVIRONMENTAL_STRESS_CLASS, config.DEFAULT_GROWTH_STAGE, None

    env_class = environmental_payload.get("stress_type") or config.DEFAULT_ENVIRONMENTAL_STRESS_CLASS
    growth_stage = environmental_payload.get("growth_stage") or config.DEFAULT_GROWTH_STAGE
    risk_60m_level = (environmental_payload.get("risk_60m") or {}).get("level")
    return env_class, growth_stage, risk_60m_level


def fuse_inputs(
    rgb_payload: dict | None = None,
    thermal_payload: dict | None = None,
    environmental_payload: dict | None = None,
) -> dict:
    """Combines whichever of the three upstream payloads are available into
    the representation knowledge_base.apply_rules expects."""
    evidence_items: list[dict] = []

    rgb_evidence = _normalize_rgb(rgb_payload)
    if rgb_evidence:
        evidence_items.append(rgb_evidence)

    thermal_evidence, thermal_heat_signal, thermal_confound = _normalize_thermal(thermal_payload)
    if thermal_evidence:
        evidence_items.append(thermal_evidence)

    environmental_stress_class, growth_stage, risk_60m_level = _normalize_environmental(environmental_payload)

    # If Thermal independently detected a heat signature but the
    # environmental sensor component reported no significant stress (or
    # wasn't available at all), still surface that as environmental
    # context - this is exactly the "don't assume 100% exact cause, but
    # don't discard the signal either" nuance from the Thermal component's
    # own design (see Thermal-stress-evidence-identify's analysis doc).
    if thermal_heat_signal and environmental_stress_class == config.DEFAULT_ENVIRONMENTAL_STRESS_CLASS:
        environmental_stress_class = "Heat Stress"

    flags = {problem: False for problem in config.PRIORITY_ORDER}
    severities: dict[str, str] = {}
    for item in evidence_items:
        flags[item["problem"]] = True
        severities[item["problem"]] = _severity_rank_max(severities.get(item["problem"]), item["severity"])

    return {
        "flags": flags,
        "severities": severities,
        "environmental_stress_class": environmental_stress_class,
        "growth_stage": growth_stage,
        "evidence": evidence_items,
        "possible_environmental_confound": thermal_confound,
        "risk_60m_level": risk_60m_level,
    }
