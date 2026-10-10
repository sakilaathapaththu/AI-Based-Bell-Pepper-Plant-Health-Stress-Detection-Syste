"""
Adaptive Recovery Decision Support - deterministic rule engine +
Gemini-based farmer explanation layer.

Ported from adaptive-recovery-decision-support/{config,fusion,
decision_engine,explanation}.py in full - including the Gemini rephrasing
step. Gemini only rephrases the already-decided rule-based text in plain
language; it never decides the action/priority/severity itself. If
GEMINI_API_KEY is not set, or the API call fails for any reason, this falls
back to the rule-based why_this_action text untouched.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

GEMINI_API_KEY_ENV_VAR = "GEMINI_API_KEY"
GEMINI_MODEL_NAME = os.environ.get("GEMINI_MODEL_NAME", "gemini-2.5-flash")

_gemini_client = None
_gemini_client_init_attempted = False


def _get_gemini_client():
    global _gemini_client, _gemini_client_init_attempted
    if _gemini_client_init_attempted:
        return _gemini_client

    _gemini_client_init_attempted = True
    api_key = os.environ.get(GEMINI_API_KEY_ENV_VAR)
    if not api_key:
        return None

    try:
        from google import genai

        _gemini_client = genai.Client(api_key=api_key)
    except Exception as exc:  # pragma: no cover - defensive, missing package/bad key
        print(f"[adaptive_service] Gemini client unavailable, falling back to rule-based text: {exc}")
        _gemini_client = None

    return _gemini_client


def _build_gemini_prompt(decision: dict, evidence: list[dict]) -> str:
    evidence_lines = "\n".join(
        f"- {item['source']} detected {item['problem'].replace('_', ' ')} "
        f"(severity: {item['severity']}, confidence: {item.get('confidence')})"
        for item in evidence
    ) or "- No stress/pest evidence was flagged by the upstream components."

    return (
        "You are writing a short, plain-language explanation for a greenhouse "
        "worker who is not a technical expert. Do NOT change or contradict the "
        "decision below - only explain it clearly and reassuringly in 2-3 "
        "sentences. Do not invent any new recommendation, severity, or priority.\n\n"
        f"Plant condition: {decision['primary_problem']}\n"
        f"Severity: {decision['severity']}\n"
        f"Priority: {decision['priority']}\n"
        f"Recommended action: {decision['recommended_action']}\n"
        f"Secondary action: {decision['secondary_action']}\n"
        f"Growth stage: {decision['growth_stage']}\n"
        f"Environmental context: {decision['environmental_context']}\n"
        f"Evidence:\n{evidence_lines}\n\n"
        "Write the explanation now:"
    )


def generate_farmer_explanation(decision: dict, evidence: list[dict]) -> dict:
    """Returns {"text": str, "source": "gemini"|"rule_based_fallback"}."""
    client = _get_gemini_client()
    if client is None:
        return {"text": decision["why_this_action"], "source": "rule_based_fallback"}

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL_NAME,
            contents=_build_gemini_prompt(decision, evidence),
        )
        text = (response.text or "").strip()
        if not text:
            raise ValueError("Empty response from Gemini")
        return {"text": text, "source": "gemini"}
    except Exception as exc:  # pragma: no cover - defensive, network/quota/API errors
        print(f"[adaptive_service] Gemini call failed, falling back to rule-based text: {exc}")
        return {"text": decision["why_this_action"], "source": "rule_based_fallback"}


PRIORITY_ORDER = ["Water_Deficit", "Thrips", "Aphid", "Nutrient_Deficiency"]
HEALTHY_LABEL = "Healthy"

DISPLAY_NAME = {
    "Water_Deficit": "Water Deficit",
    "Nutrient_Deficiency": "Nutrient Deficiency",
    "Aphid": "Aphid",
    "Thrips": "Thrips",
    "Healthy": "Healthy",
}

ACTION_TEMPLATES = {
    "Water_Deficit": "Apply appropriate irrigation based on root-zone moisture and continue moisture monitoring.",
    "Thrips": "Increase thrips monitoring and implement appropriate integrated pest-management measures.",
    "Aphid": "Increase aphid monitoring and implement appropriate integrated pest-management measures.",
    "Nutrient_Deficiency": "Assess soil/plant nutrient status and apply corrective nutrient management according to the identified deficiency.",
    "Healthy": "Continue routine monitoring and maintain suitable greenhouse conditions.",
}

SECONDARY_ACTION_NONE_PRESENT = "No recovery intervention required."
SECONDARY_ACTION_ONLY_PRIMARY_PRESENT = "Continue monitoring for changes."

HEAT_LOAD_ADDENDUM = " Reduce environmental heat/load where practical."
HEAT_LOAD_ADDENDUM_TRIGGER_PROBLEM = "Water_Deficit"
HEAT_LOAD_ADDENDUM_TRIGGER_ENV_CLASSES = {
    "Heat Stress", "Combined Environmental Stress", "High Light Stress", "Low Humidity Stress",
}

SEVERITY_TO_PRIORITY = {"High": "High", "Medium": "Medium", "Low": "Medium"}
HEALTHY_PRIORITY = "Low"

RISK_ESCALATION_TRIGGER_LEVEL = "High"
RISK_ESCALATION_FROM_PRIORITY = "Medium"
RISK_ESCALATION_TO_PRIORITY = "High"

SEVERITY_LEVEL_MAP = {"Mild": "Low", "Moderate": "Medium", "Severe": "High"}
SEVERITY_RANK = {"Low": 0, "Medium": 1, "High": 2}
DEFAULT_SEVERITY_IF_UNSPECIFIED = "Medium"

WHY_TEMPLATE = "{problem} is indicated at the {severity_lower} level during the {growth_stage} stage. Environmental context: {env_class}."
WHY_HEALTHY_TEXT = "No plant stress or pest condition is indicated by the component outputs."

AGRONOMIC_EVIDENCE_STATUS = "Agronomic source to be linked and verified - pending expert validation"

THERMAL_CLASS_TO_PROBLEM = {"Water_Stress": "Water_Deficit", "Nutrient_Stress": "Nutrient_Deficiency"}
THERMAL_HEAT_CLASS = "Heat_Stress"
DEFAULT_ENVIRONMENTAL_STRESS_CLASS = "No Significant Environmental Stress"
DEFAULT_GROWTH_STAGE = "Unknown"


def _severity_rank_max(current: str | None, candidate: str) -> str:
    if current is None:
        return candidate
    return candidate if SEVERITY_RANK[candidate] > SEVERITY_RANK[current] else current


def _normalize_rgb(rgb_payload: dict | None) -> dict | None:
    if not rgb_payload or rgb_payload.get("plant_condition") != "Stressed":
        return None
    problem = rgb_payload.get("stress_type")
    if problem not in PRIORITY_ORDER:
        return None
    severity = SEVERITY_LEVEL_MAP.get(rgb_payload.get("severity"), DEFAULT_SEVERITY_IF_UNSPECIFIED)
    return {"problem": problem, "severity": severity, "source": "RGB", "confidence": rgb_payload.get("confidence")}


def _normalize_thermal(thermal_payload: dict | None) -> tuple[dict | None, bool, bool]:
    if not thermal_payload or thermal_payload.get("stress_status") != "Stressed":
        return None, False, False

    thermal_class = thermal_payload.get("stress_type")
    confound = bool(thermal_payload.get("possible_environmental_confound", False))

    if thermal_class == THERMAL_HEAT_CLASS:
        return None, True, confound

    problem = THERMAL_CLASS_TO_PROBLEM.get(thermal_class)
    if problem is None:
        return None, False, confound

    severity = SEVERITY_LEVEL_MAP.get(thermal_payload.get("severity"), DEFAULT_SEVERITY_IF_UNSPECIFIED)
    evidence = {
        "problem": problem, "severity": severity, "source": "Thermal",
        "confidence": thermal_payload.get("model_confidence"),
    }
    return evidence, False, confound


def _normalize_environmental(environmental_payload: dict | None) -> tuple[str, str, str | None]:
    if not environmental_payload:
        return DEFAULT_ENVIRONMENTAL_STRESS_CLASS, DEFAULT_GROWTH_STAGE, None
    env_class = environmental_payload.get("stress_type") or DEFAULT_ENVIRONMENTAL_STRESS_CLASS
    growth_stage = environmental_payload.get("growth_stage") or DEFAULT_GROWTH_STAGE
    risk_60m_level = (environmental_payload.get("risk_60m") or {}).get("level")
    return env_class, growth_stage, risk_60m_level


def fuse_inputs(rgb_payload: dict | None, thermal_payload: dict | None, environmental_payload: dict | None) -> dict:
    evidence_items: list[dict] = []

    rgb_evidence = _normalize_rgb(rgb_payload)
    if rgb_evidence:
        evidence_items.append(rgb_evidence)

    thermal_evidence, thermal_heat_signal, thermal_confound = _normalize_thermal(thermal_payload)
    if thermal_evidence:
        evidence_items.append(thermal_evidence)

    environmental_stress_class, growth_stage, risk_60m_level = _normalize_environmental(environmental_payload)

    if thermal_heat_signal and environmental_stress_class == DEFAULT_ENVIRONMENTAL_STRESS_CLASS:
        environmental_stress_class = "Heat Stress"

    flags = {problem: False for problem in PRIORITY_ORDER}
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


def select_primary_problem(flags: dict[str, bool]) -> str | None:
    for problem in PRIORITY_ORDER:
        if flags.get(problem):
            return problem
    return None


def select_secondary_action(flags: dict[str, bool], primary_problem: str | None) -> str:
    if primary_problem is None:
        return SECONDARY_ACTION_NONE_PRESENT
    remaining = [p for p in PRIORITY_ORDER if p != primary_problem and flags.get(p)]
    if remaining:
        return ACTION_TEMPLATES[remaining[0]]
    return SECONDARY_ACTION_ONLY_PRIMARY_PRESENT


def build_recommended_action(primary_problem: str | None, environmental_stress_class: str) -> str:
    if primary_problem is None:
        return ACTION_TEMPLATES[HEALTHY_LABEL]
    action = ACTION_TEMPLATES[primary_problem]
    if (
        primary_problem == HEAT_LOAD_ADDENDUM_TRIGGER_PROBLEM
        and environmental_stress_class in HEAT_LOAD_ADDENDUM_TRIGGER_ENV_CLASSES
    ):
        action += HEAT_LOAD_ADDENDUM
    return action


def severity_to_priority(severity: str | None) -> str:
    if severity is None:
        return HEALTHY_PRIORITY
    return SEVERITY_TO_PRIORITY.get(severity, "Medium")


def escalate_priority_for_forecast_risk(priority: str, risk_60m_level: str | None) -> str:
    if priority == RISK_ESCALATION_FROM_PRIORITY and risk_60m_level == RISK_ESCALATION_TRIGGER_LEVEL:
        return RISK_ESCALATION_TO_PRIORITY
    return priority


def build_why_text(primary_problem: str | None, severity: str | None, growth_stage: str, environmental_stress_class: str) -> str:
    if primary_problem is None:
        return WHY_HEALTHY_TEXT
    display_problem = DISPLAY_NAME.get(primary_problem, primary_problem)
    severity_text = (severity or DEFAULT_SEVERITY_IF_UNSPECIFIED).lower()
    return WHY_TEMPLATE.format(
        problem=display_problem, severity_lower=severity_text, growth_stage=growth_stage, env_class=environmental_stress_class,
    )


def apply_rules(flags: dict[str, bool], severities: dict[str, str], growth_stage: str, environmental_stress_class: str, risk_60m_level: str | None = None) -> dict:
    primary_problem = select_primary_problem(flags)
    severity = severities.get(primary_problem) if primary_problem else None
    priority = escalate_priority_for_forecast_risk(severity_to_priority(severity), risk_60m_level)

    return {
        "primary_problem": DISPLAY_NAME.get(primary_problem, HEALTHY_LABEL),
        "severity": severity or "None",
        "priority": priority,
        "growth_stage": growth_stage,
        "environmental_context": environmental_stress_class,
        "recommended_action": build_recommended_action(primary_problem, environmental_stress_class),
        "secondary_action": select_secondary_action(flags, primary_problem),
        "why_this_action": build_why_text(primary_problem, severity, growth_stage, environmental_stress_class),
        "agronomic_evidence_status": AGRONOMIC_EVIDENCE_STATUS,
    }


def generate_recovery_plan(plant_id: str | None, rgb_result: dict | None, thermal_result: dict | None, environmental_result: dict | None) -> dict:
    fused = fuse_inputs(rgb_result, thermal_result, environmental_result)
    decision = apply_rules(
        flags=fused["flags"],
        severities=fused["severities"],
        growth_stage=fused["growth_stage"],
        environmental_stress_class=fused["environmental_stress_class"],
        risk_60m_level=fused["risk_60m_level"],
    )

    farmer_explanation = generate_farmer_explanation(decision, fused["evidence"])

    return {
        "plant_id": plant_id,
        "recommended_action": decision["recommended_action"],
        "priority": decision["priority"],
        "why_this_action": farmer_explanation["text"],
        "why_this_action_source": farmer_explanation["source"],
        "supporting_evidence": fused["evidence"],
        "details": {
            "primary_problem": decision["primary_problem"],
            "severity": decision["severity"],
            "secondary_action": decision["secondary_action"],
            "environmental_context": fused["environmental_stress_class"],
            "growth_stage": fused["growth_stage"],
            "possible_environmental_confound": fused["possible_environmental_confound"],
            "agronomic_evidence_status": decision["agronomic_evidence_status"],
            "inputs_received": {
                "rgb": rgb_result is not None,
                "thermal": thermal_result is not None,
                "environmental": environmental_result is not None,
            },
        },
    }
