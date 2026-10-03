"""
Classical (non-deep-learning) thermal image-quality gate.

Runs BEFORE the trained model, matching the described flow: "If Image [has]
blur, incomplete, invalid thermal data... flag/reject it." Implemented with
classical computer vision (no neural network) so it is instant.

Thermal-specific failure mode this checks for, beyond blur: a stuck or
saturated thermal sensor reads back as a near-uniform color block (very low
pixel variance) rather than a real temperature gradient - this looks
nothing like a "dark" RGB photo, so it needs its own check (min_pixel_std)
rather than reusing the RGB component's brightness-range check as-is.

IMPORTANT: thresholds in config.py are starting points only. Re-tune them
against deliberately bad/corrupt thermal captures, since the curated
dataset contains only already-good frames (see analysis doc Section 4,
step 1).

This file only DEFINES functions. Nothing runs on import. To manually check
a single image, run:

    python quality_gate.py path/to/thermal_frame.png
"""

from __future__ import annotations

import sys

import cv2
import numpy as np

import config


def blur_score(gray_image: np.ndarray) -> float:
    """Variance of the Laplacian. Lower values = blurrier image."""
    return float(cv2.Laplacian(gray_image, cv2.CV_64F).var())


def pixel_std(gray_image: np.ndarray) -> float:
    """Overall pixel-intensity standard deviation. A near-flat/stuck sensor
    frame has very low variance regardless of blur, so this is checked
    separately from blur_score."""
    return float(np.std(gray_image))


def assess_image_quality(image_path: str) -> dict:
    """Returns a dict describing whether the thermal frame should be
    accepted, plus the specific reason if rejected - map straight to the
    app's 'Image unclear / invalid thermal data. Please retake.' message
    when accepted=False.
    """
    image = cv2.imread(image_path)
    if image is None:
        return {"accepted": False, "reason": "unreadable_file"}

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    blur = blur_score(gray)
    std = pixel_std(gray)

    result = {
        "accepted": True,
        "reason": None,
        "metrics": {"blur_score": blur, "pixel_std": std},
    }

    if blur < config.BLUR_LAPLACIAN_VAR_THRESHOLD:
        result["accepted"] = False
        result["reason"] = "blurry"
    elif std < config.MIN_PIXEL_STD:
        result["accepted"] = False
        result["reason"] = "flat_or_stuck_sensor_frame"

    return result


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python quality_gate.py path/to/thermal_frame.png
    if len(sys.argv) != 2:
        print("Usage: python quality_gate.py <image_path>")
        sys.exit(1)

    outcome = assess_image_quality(sys.argv[1])
    print(outcome)
