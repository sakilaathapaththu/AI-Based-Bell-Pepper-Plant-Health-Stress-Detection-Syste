"""
Deterministic rule engine for the Adaptive Recovery Decision Support System
(Component 4).

Every function here implements one of the five reverse-engineered rules
documented in config.py, operating on a plain "fused" representation
(flags/severities/environmental context) rather than on any particular
upstream component's raw payload shape - that translation step lives in
fusion.py, kept separate so these rules can be tested directly against the
reference spreadsheet in validate_against_dataset.py.

Nothing in this file executes on import.
"""

from __future__ import annotations

import config


def select_primary_problem(flags: dict[str, bool]) -> str | None:
    """Rule 1: fixed priority order. Returns None if no problem is flagged
    (i.e. the plant is Healthy)."""
    for problem in config.PRIORITY_ORDER:
        if flags.get(problem):
            return problem
    return None


def select_secondary_action(flags: dict[str, bool], primary_problem: str | None) -> str:
    """Rule 2: action for the next-highest-priority flagged problem still
    present, or a fixed fallback sentence."""
    if primary_problem is None:
        return config.SECONDARY_ACTION_NONE_PRESENT

    remaining = [p for p in config.PRIORITY_ORDER if p != primary_problem and flags.get(p)]
    if remaining:
        next_problem = remaining[0]  # config.PRIORITY_ORDER is already priority-sorted
        return config.ACTION_TEMPLATES[next_problem]

    return config.SECONDARY_ACTION_ONLY_PRIMARY_PRESENT


def build_recommended_action(primary_problem: str | None, environmental_stress_class: str) -> str:
    """Rule 3: fixed action template per problem, plus the one conditional
    heat/load addendum found in the reference dataset."""
    if primary_problem is None:
        return config.ACTION_TEMPLATES[config.HEALTHY_LABEL]

    action = config.ACTION_TEMPLATES[primary_problem]
    if (
        primary_problem == config.HEAT_LOAD_ADDENDUM_TRIGGER_PROBLEM
        and environmental_stress_class in config.HEAT_LOAD_ADDENDUM_TRIGGER_ENV_CLASSES
    ):
        action += config.HEAT_LOAD_ADDENDUM
    return action


def severity_to_priority(severity: str | None) -> str:
    """Rule 4: collapses Severity (High/Medium/Low) into Priority
    (High/Medium/Low), or Low priority if the plant is Healthy
    (severity=None)."""
    if severity is None:
        return config.HEALTHY_PRIORITY
    return config.SEVERITY_TO_PRIORITY.get(severity, "Medium")


def escalate_priority_for_forecast_risk(priority: str, risk_60m_level: str | None) -> str:
    """Rule 4b (enhancement, not from the reference spreadsheet - see
    config.py): escalates Medium priority to High if the environmental
    component's 60-minute-ahead forecast is already "High" risk, so a
    worsening-but-not-yet-severe case still gets flagged urgently. Never
    touches Low priority (Healthy plants) or an already-High priority."""
    if priority == config.RISK_ESCALATION_FROM_PRIORITY and risk_60m_level == config.RISK_ESCALATION_TRIGGER_LEVEL:
        return config.RISK_ESCALATION_TO_PRIORITY
    return priority


def build_why_text(
    primary_problem: str | None,
    severity: str | None,
    growth_stage: str,
    environmental_stress_class: str,
) -> str:
    """Rule 5: fixed string template."""
    if primary_problem is None:
        return config.WHY_HEALTHY_TEXT

    display_problem = config.DISPLAY_NAME.get(primary_problem, primary_problem)
    severity_text = (severity or config.DEFAULT_SEVERITY_IF_UNSPECIFIED).lower()
    return config.WHY_TEMPLATE.format(
        problem=display_problem,
        severity_lower=severity_text,
        growth_stage=growth_stage,
        env_class=environmental_stress_class,
    )


def apply_rules(
    flags: dict[str, bool],
    severities: dict[str, str],
    growth_stage: str,
    environmental_stress_class: str,
    risk_60m_level: str | None = None,
) -> dict:
    """Runs all five rules (plus the 4b risk-escalation enhancement) in
    sequence and returns the full structured decision - the deterministic
    core of Component 4, before the Gemini explanation layer
    (explanation.py) ever sees it. risk_60m_level defaults to None, which
    makes Rule 4b inert - this keeps validate_against_dataset.py's 100%
    match against the reference spreadsheet unaffected, since that dataset
    has no equivalent column."""
    primary_problem = select_primary_problem(flags)
    severity = severities.get(primary_problem) if primary_problem else None
    priority = escalate_priority_for_forecast_risk(severity_to_priority(severity), risk_60m_level)

    return {
        "primary_problem": config.DISPLAY_NAME.get(primary_problem, config.HEALTHY_LABEL),
        "severity": severity or "None",
        "priority": priority,
        "recommended_action": build_recommended_action(primary_problem, environmental_stress_class),
        "secondary_action": select_secondary_action(flags, primary_problem),
        "why_this_action": build_why_text(primary_problem, severity, growth_stage, environmental_stress_class),
        "agronomic_evidence_status": config.AGRONOMIC_EVIDENCE_STATUS,
    }
