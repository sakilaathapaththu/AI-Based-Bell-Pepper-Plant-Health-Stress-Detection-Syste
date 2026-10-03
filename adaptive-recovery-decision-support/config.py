"""
Adaptive Recovery Decision Support System (Component 4) - shared
configuration and rule constants.

Every constant in this file was REVERSE-ENGINEERED from
dataset_all/practical recovery recommendatio/Component_4_Recovery_Plan_500_Cases
(1)   - corrected.xlsx (500 synthetic decision cases) and verified to match
100% of non-severity fields across all 500 rows (see
validate_against_dataset.py). This is a deterministic rule engine, not a
trained ML model - there is no labeled "correct recovery action" dataset to
train a classifier on, and the source spreadsheet itself is fully
rule-generated (see its README sheet: "Synthetic/illustrative, not measured
observations").

Nothing in this file executes on import.
"""

from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

# Local copy, seeded from dataset_all/practical recovery recommendatio/ -
# kept inside this component's own folder (same convention as
# rgb-stress-detection/dataset/ and Thermal-stress-evidence-identify/dataset/)
# so this component is self-contained.
REFERENCE_DATASET_PATH = BASE_DIR / "dataset" / "Component_4_Recovery_Plan_500_Cases (1)   - corrected.xlsx"

# ---------------------------------------------------------------------------
# Rule 1: Primary Problem selection - FIXED priority order among
# simultaneously-flagged problems. Verified against all 500 reference rows:
# whenever Water_Deficit is flagged, it is chosen as primary 169/169 times
# regardless of what else is flagged; Thrips beats Aphid and
# Nutrient_Deficiency whenever Water_Deficit is absent; Aphid beats
# Nutrient_Deficiency. Growth stage and environmental conditions do NOT
# change this ordering in the reference dataset.
# ---------------------------------------------------------------------------
PRIORITY_ORDER = ["Water_Deficit", "Thrips", "Aphid", "Nutrient_Deficiency"]

HEALTHY_LABEL = "Healthy"

# Display text matches the reference spreadsheet's Primary_Problem column
# exactly (space-separated, not underscore).
DISPLAY_NAME = {
    "Water_Deficit": "Water Deficit",
    "Nutrient_Deficiency": "Nutrient Deficiency",
    "Aphid": "Aphid",
    "Thrips": "Thrips",
    "Healthy": "Healthy",
}

# ---------------------------------------------------------------------------
# Rule 3: Recommended Action - fixed template per problem (verified to
# match the reference dataset's Recommended_Action/Secondary_Action base
# text exactly, before the conditional heat/load addendum below).
# ---------------------------------------------------------------------------
ACTION_TEMPLATES = {
    "Water_Deficit": "Apply appropriate irrigation based on root-zone moisture and continue moisture monitoring.",
    "Thrips": "Increase thrips monitoring and implement appropriate integrated pest-management measures.",
    "Aphid": "Increase aphid monitoring and implement appropriate integrated pest-management measures.",
    "Nutrient_Deficiency": "Assess soil/plant nutrient status and apply corrective nutrient management according to the identified deficiency.",
    "Healthy": "Continue routine monitoring and maintain suitable greenhouse conditions.",
}

SECONDARY_ACTION_NONE_PRESENT = "No recovery intervention required."
SECONDARY_ACTION_ONLY_PRIMARY_PRESENT = "Continue monitoring for changes."

# The ONLY conditional clause found in the reference dataset: appended to
# the Water_Deficit action, and ONLY when the environmental context is one
# of these four classes - verified with zero exceptions across all 500 rows
# (checked every Primary_Problem x Environmental_Stress_Class combination).
HEAT_LOAD_ADDENDUM = " Reduce environmental heat/load where practical."
HEAT_LOAD_ADDENDUM_TRIGGER_PROBLEM = "Water_Deficit"
HEAT_LOAD_ADDENDUM_TRIGGER_ENV_CLASSES = {
    "Heat Stress",
    "Combined Environmental Stress",
    "High Light Stress",
    "Low Humidity Stress",
}

# ---------------------------------------------------------------------------
# Rule 4: Severity -> Priority collapse (verified with zero exceptions).
# Severity itself is NOT reverse-engineerable from growth stage/environment
# in the reference dataset (it varies within each problem type without a
# clean pattern) - do not try to re-derive it here. Instead, fuse Severity
# from the upstream components' own Mild/Moderate/Severe outputs (see
# fusion.py SEVERITY_LEVEL_MAP) - this is the one place where this
# component's logic is a deliberate design choice, not a literal
# reproduction of the reference spreadsheet's internal (likely randomly
# sampled) severity assignment.
# ---------------------------------------------------------------------------
SEVERITY_TO_PRIORITY = {"High": "High", "Medium": "Medium", "Low": "Medium"}
HEALTHY_PRIORITY = "Low"

# ---------------------------------------------------------------------------
# Rule 4b (deliberate enhancement, NOT part of the reference spreadsheet):
# priority escalation from the environmental component's own 60-minute-ahead
# risk forecast. Severity alone only reflects the plant's CURRENT visible/
# thermal condition - if conditions are forecast to get significantly worse
# soon, that is a genuinely useful urgency signal the farmer should see,
# even before optical/thermal severity has caught up to it.
#
# Deliberately scoped narrow (Medium -> High only, never touches Low or an
# already-High priority, and only fires when risk_60m.level is explicitly
# "High") so this is an auditable ADDITION on top of the validated Rules
# 1-5, not a replacement of them - see validate_against_dataset.py, which
# does not exercise this rule (the reference dataset has no risk_60m
# column) and still matches 100% with this rule present but inactive.
# ---------------------------------------------------------------------------
RISK_ESCALATION_TRIGGER_LEVEL = "High"
RISK_ESCALATION_FROM_PRIORITY = "Medium"
RISK_ESCALATION_TO_PRIORITY = "High"

# Maps the RGB/Thermal components' Mild/Moderate/Severe severity (see
# rgb-stress-detection/app.py and Thermal-stress-evidence-identify/app.py)
# onto the reference dataset's High/Medium/Low severity vocabulary.
SEVERITY_LEVEL_MAP = {"Mild": "Low", "Moderate": "Medium", "Severe": "High"}
SEVERITY_RANK = {"Low": 0, "Medium": 1, "High": 2}
DEFAULT_SEVERITY_IF_UNSPECIFIED = "Medium"

# ---------------------------------------------------------------------------
# Rule 5: "Why This Action" text - fixed string template (verified to match
# 100% of non-Healthy reference rows exactly; Healthy rows use the fixed
# sentence below instead).
# ---------------------------------------------------------------------------
WHY_TEMPLATE = "{problem} is indicated at the {severity_lower} level during the {growth_stage} stage. Environmental context: {env_class}."
WHY_HEALTHY_TEXT = "No plant stress or pest condition is indicated by the component outputs."

# The reference dataset's Agronomic_Evidence column is a constant
# placeholder in all 500 rows ("Agronomic source to be linked and
# verified"), not real citations - carried over here as an explicit honesty
# flag rather than silently inventing citations.
AGRONOMIC_EVIDENCE_STATUS = "Agronomic source to be linked and verified - pending expert validation"

# ---------------------------------------------------------------------------
# Fusion: maps Thermal component's class names onto this component's
# problem taxonomy. Heat_Stress has no Primary_Problem slot in this
# taxonomy (Heat Stress is an environmental/sensor-scope class, not a
# leaf-visible biotic/water/nutrient problem - see rgb-stress-detection's
# and the environmental component's own scope notes) - it instead
# contributes to the environmental-context signal only.
# ---------------------------------------------------------------------------
THERMAL_CLASS_TO_PROBLEM = {
    "Water_Stress": "Water_Deficit",
    "Nutrient_Stress": "Nutrient_Deficiency",
}
THERMAL_HEAT_CLASS = "Heat_Stress"
DEFAULT_ENVIRONMENTAL_STRESS_CLASS = "No Significant Environmental Stress"
DEFAULT_GROWTH_STAGE = "Unknown"

# ---------------------------------------------------------------------------
# Gemini API - used ONLY for the farmer-facing explanation/language layer
# (see explanation.py). The recommended action, priority, and why-text are
# already fully decided by the deterministic rules above BEFORE Gemini is
# ever called - Gemini only rephrases that decision in plain language, it
# never decides the action itself. If no API key is configured, or the API
# call fails for any reason, the system falls back to the rule-based
# why_this_action text untouched - this component must keep working with
# zero internet/API access.
# ---------------------------------------------------------------------------
GEMINI_API_KEY_ENV_VAR = "GEMINI_API_KEY"
GEMINI_MODEL_NAME = "gemini-2.5-flash"
