"""
Virtual Sensor / Dataset Replay lookup.

The UI flow never asks the user to re-enter or supply prior readings -
"current environmental inputs ටිකම AI model එක reuse කරනවා" (spec). Since
no physical sensor exists yet, the 30/60-min forecast models still need
~3 hours of prior readings to compute lag/rolling/trend features. This
module supplies that history automatically from the shipped replay/training
data by matching growth stage + time-of-day, so callers of /predict only
ever send the single current reading.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

BASE_DIR = Path(__file__).resolve().parent
REPLAY_SOURCE_PATH = BASE_DIR / "Dataset" / "model_training_table.csv"

HISTORY_COLUMNS = [
    "timestamp",
    "growth_stage",
    "air_temperature_c",
    "relative_humidity_pct",
    "light_intensity_lux",
    "soil_temperature_c",
]

_cache: pd.DataFrame | None = None


def _load_replay_source(path: Path = REPLAY_SOURCE_PATH) -> pd.DataFrame:
    global _cache
    if _cache is None:
        df = pd.read_csv(path, usecols=HISTORY_COLUMNS)
        df["timestamp"] = pd.to_datetime(df["timestamp"])
        df = df.sort_values("timestamp").reset_index(drop=True)
        df["_minute_of_day"] = df["timestamp"].dt.hour * 60 + df["timestamp"].dt.minute
        _cache = df
    return _cache


def get_historical_context(
    growth_stage: str,
    hour: int,
    minute: int,
    window: int = 6,
    path: Path = REPLAY_SOURCE_PATH,
) -> list[dict]:
    """Return `window` prior readings (chronological, 30min apart) for the
    given growth stage, ending at the replay row whose time-of-day is
    closest to (hour, minute). Falls back to the earliest `window` rows for
    that stage if there isn't enough history before the matched point."""
    df = _load_replay_source(path)
    stage_df = df[df["growth_stage"] == growth_stage].reset_index(drop=True)
    if stage_df.empty:
        raise ValueError(f"No replay history available for growth_stage: {growth_stage}")

    target_minute = hour * 60 + minute
    closest_idx = (stage_df["_minute_of_day"] - target_minute).abs().idxmin()

    start = max(0, closest_idx - window + 1)
    end = closest_idx + 1
    if end - start < window:
        end = min(len(stage_df), start + window)

    history = stage_df.iloc[start:end][HISTORY_COLUMNS].copy()
    history["timestamp"] = history["timestamp"].astype(str)
    return history.to_dict(orient="records")
