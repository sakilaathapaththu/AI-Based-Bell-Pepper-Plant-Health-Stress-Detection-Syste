"""
Regression test: runs knowledge_base.apply_rules directly against every row
of the 500-case reference spreadsheet (dataset_all/practical recovery
recommendatio/Component_4_Recovery_Plan_500_Cases (1)   - corrected.xlsx)
and checks that the rule engine's output matches the reference exactly.

This bypasses fusion.py deliberately - the reference spreadsheet already
has clean Yes/No flag columns and a growth-stage/environmental-class
column, so this test targets knowledge_base.py's rule logic directly,
isolating it from any upstream-payload-shape assumptions in fusion.py.

Severity is NOT checked for an exact match (see config.py: severity is not
cleanly derivable from the reference dataset's own inputs, so it is sourced
from upstream components in production, not re-derived here) - everything
else (Primary_Problem, Secondary_Action, Recommended_Action, Priority,
Why_This_Action) IS checked for an exact match, using the reference
dataset's OWN Severity column as the input to isolate rule correctness from
severity-sourcing.

This file only DEFINES a function. Nothing runs on import. To run the
validation, run:

    python validate_against_dataset.py

which prints a per-field match rate and writes any mismatches to
reports/validation_mismatches.csv.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

import config
import knowledge_base

REPORTS_DIR = Path(__file__).resolve().parent / "reports"

FLAG_COLUMNS = ["Water_Deficit", "Thrips", "Aphid", "Nutrient_Deficiency"]


def _row_to_fused_inputs(row: pd.Series) -> dict:
    flags = {col: row[col] == "Yes" for col in FLAG_COLUMNS}
    primary_problem = knowledge_base.select_primary_problem(flags)
    # The reference dataset's own Severity value for THIS row is fed
    # straight back in as the "fused" severity for the primary problem,
    # since severity-sourcing is deliberately out of scope for this rule
    # engine (see module docstring) - this isolates whether the five RULES
    # are correct, independent of where severity numbers come from.
    severities = {}
    if primary_problem is not None and pd.notna(row["Severity"]):
        severities[primary_problem] = row["Severity"]

    return {
        "flags": flags,
        "severities": severities,
        "growth_stage": row["Growth_Stage"],
        "environmental_stress_class": row["Environmental_Stress_Class"],
    }


def run(dataset_path: Path = config.REFERENCE_DATASET_PATH) -> None:
    df = pd.read_excel(dataset_path, sheet_name="Recovery_Plan_500")

    fields_to_check = [
        ("Primary_Problem", "primary_problem"),
        ("Secondary_Action", "secondary_action"),
        ("Recommended_Action", "recommended_action"),
        ("Priority", "priority"),
        ("Why_This_Action", "why_this_action"),
    ]

    match_counts = {field: 0 for field, _ in fields_to_check}
    mismatches = []

    for _, row in df.iterrows():
        fused = _row_to_fused_inputs(row)
        decision = knowledge_base.apply_rules(
            flags=fused["flags"],
            severities=fused["severities"],
            growth_stage=fused["growth_stage"],
            environmental_stress_class=fused["environmental_stress_class"],
        )

        row_mismatch = {"Case_ID": row["Case_ID"]}
        any_mismatch = False
        for excel_col, decision_key in fields_to_check:
            expected = row[excel_col]
            actual = decision[decision_key]
            if expected == actual:
                match_counts[excel_col] += 1
            else:
                any_mismatch = True
                row_mismatch[f"{excel_col}_expected"] = expected
                row_mismatch[f"{excel_col}_actual"] = actual

        if any_mismatch:
            mismatches.append(row_mismatch)

    total = len(df)
    print(f"[validate] Checked {total} reference cases.\n")
    for excel_col, _ in fields_to_check:
        rate = match_counts[excel_col] / total
        print(f"  {excel_col}: {match_counts[excel_col]}/{total} exact matches ({rate:.1%})")

    if mismatches:
        REPORTS_DIR.mkdir(parents=True, exist_ok=True)
        out_path = REPORTS_DIR / "validation_mismatches.csv"
        pd.DataFrame(mismatches).to_csv(out_path, index=False)
        print(f"\n[validate] {len(mismatches)} row(s) had at least one mismatch - details written to {out_path}")
    else:
        print("\n[validate] All fields matched exactly on every reference case.")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python validate_against_dataset.py
    run()
