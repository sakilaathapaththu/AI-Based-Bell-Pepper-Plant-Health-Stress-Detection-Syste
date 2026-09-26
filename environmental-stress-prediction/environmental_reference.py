"""
Rule-based reference-range lookup used by:
- "Check Current Environment" (compare live readings to suitable ranges)
- "Main Contributing Factors" explanation attached to /predict output

Ranges come from Dataset/bell_pepper_reference_ranges.csv (literature-informed
prototype values - see dataset/.../02_Bell_Pepper_References). This module
never invents thresholds; it only reads the shipped reference table.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

BASE_DIR = Path(__file__).resolve().parent
REFERENCE_RANGES_PATH = BASE_DIR / "Dataset" / "bell_pepper_reference_ranges.csv"

DAY_START_HOUR = 6
DAY_END_HOUR = 18

# How far outside the suitable range counts as "Slightly" vs a hard breach,
# expressed as a fraction of the range width.
SLIGHT_BAND_FRACTION = 0.15


def load_reference_ranges(path: Path = REFERENCE_RANGES_PATH) -> pd.DataFrame:
    return pd.read_csv(path).set_index("growth_stage")


def is_daytime(hour: int) -> bool:
    return DAY_START_HOUR <= hour < DAY_END_HOUR


def _status(value: float, low: float, high: float) -> str:
    span = high - low
    slight = span * SLIGHT_BAND_FRACTION
    if value < low - slight:
        return "Low"
    if value < low:
        return "Slightly Low"
    if value > high + slight:
        return "High"
    if value > high:
        return "Slightly High"
    return "Normal"


def evaluate_current_environment(
    current_environment: dict,
    growth_stage: str,
    hour: int,
    ranges: pd.DataFrame,
) -> dict:
    """Compare current sensor readings against the suitable range for the
    given growth stage. Returns per-variable status + suitable range +
    a simple adjustment direction. Does NOT recommend an exact recovery
    action (fan/irrigation/etc.) - that belongs to the Recovery DSS."""

    if growth_stage not in ranges.index:
        raise ValueError(f"Unknown growth_stage: {growth_stage}")
    row = ranges.loc[growth_stage]
    daytime = is_daytime(hour)

    temp_low, temp_high = (
        (float(row["day_air_temp_min_c"]), float(row["day_air_temp_max_c"]))
        if daytime
        else (float(row["night_air_temp_min_c"]), float(row["night_air_temp_max_c"]))
    )

    results = {}

    air_temp = current_environment["air_temperature_c"]
    results["air_temperature_c"] = {
        "value": air_temp,
        "status": _status(air_temp, temp_low, temp_high),
        "suitable_range": [temp_low, temp_high],
    }

    humidity = current_environment["relative_humidity_pct"]
    rh_low, rh_high = float(row["rh_min_pct"]), float(row["rh_max_pct"])
    results["relative_humidity_pct"] = {
        "value": humidity,
        "status": _status(humidity, rh_low, rh_high),
        "suitable_range": [rh_low, rh_high],
    }

    soil_temp = current_environment["soil_temperature_c"]
    soil_low, soil_high = float(row["soil_temp_min_c"]), float(row["soil_temp_max_c"])
    results["soil_temperature_c"] = {
        "value": soil_temp,
        "status": _status(soil_temp, soil_low, soil_high),
        "suitable_range": [soil_low, soil_high],
    }

    light = current_environment["light_intensity_lux"]
    if daytime:
        light_low, light_high = float(row["day_light_min_lux_prototype"]), float(row["day_light_max_lux_prototype"])
        light_status = _status(light, light_low, light_high)
        light_range = [light_low, light_high]
    else:
        # Night-time low light is expected, not a stress signal.
        light_status = "Normal"
        light_range = None
    results["light_intensity_lux"] = {
        "value": light,
        "status": light_status,
        "suitable_range": light_range,
    }

    for field, info in results.items():
        info["adjustment_direction"] = _direction_text(field, info["status"])

    return results


def _direction_text(field: str, status: str) -> str | None:
    label = {
        "air_temperature_c": "temperature",
        "relative_humidity_pct": "humidity",
        "soil_temperature_c": "soil temperature",
        "light_intensity_lux": "light",
    }[field]

    if status in ("High", "Slightly High"):
        return f"Reduce {label} towards the suitable range"
    if status in ("Low", "Slightly Low"):
        return f"Increase {label} towards the suitable range"
    return None


def main_contributing_factors(environment_status: dict) -> list[str]:
    """Turn "High"/"Slightly High"/etc. statuses into human-readable factor
    strings, e.g. "High Air Temperature", ordered by severity."""
    label = {
        "air_temperature_c": "Air Temperature",
        "relative_humidity_pct": "Relative Humidity",
        "soil_temperature_c": "Soil Temperature",
        "light_intensity_lux": "Light Intensity",
    }
    severity_rank = {"High": 0, "Low": 0, "Slightly High": 1, "Slightly Low": 1, "Normal": 2}

    factors = [
        (severity_rank[info["status"]], f"{info['status']} {label[field]}")
        for field, info in environment_status.items()
        if info["status"] != "Normal"
    ]
    factors.sort(key=lambda x: x[0])
    return [text for _, text in factors]
