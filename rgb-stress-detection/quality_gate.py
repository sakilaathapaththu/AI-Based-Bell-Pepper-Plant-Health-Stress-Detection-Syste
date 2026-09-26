"""
Classical (non-deep-learning) image-quality gate.

Runs BEFORE the trained model, matching the app flow described in the
project scenario: "Image unclear. Please retake the image." must be shown
before AI processing starts. Implemented with classical computer vision
(no neural network) so it is instant and works even without the trained
model loaded - see analysis doc Section 4.2.

IMPORTANT: the thresholds in config.py are starting points only. They must
be re-tuned against a self-collected sample of deliberately blurry/dark/
miscomposed phone photos, because the curated training dataset contains
only already-good images and cannot be used to tune this gate (see analysis
doc Section 4.2 and Section 7).

This file only DEFINES functions. Nothing runs on import. To manually check
a single image, run:

    python quality_gate.py path/to/photo.jpg
"""

from __future__ import annotations

import sys

import cv2
import numpy as np

import config


def blur_score(gray_image: np.ndarray) -> float:
    """Variance of the Laplacian. Lower values = blurrier image."""
    return float(cv2.Laplacian(gray_image, cv2.CV_64F).var())


def brightness_score(gray_image: np.ndarray) -> float:
    return float(np.mean(gray_image))


def foliage_pixel_ratio(bgr_image: np.ndarray) -> float:
    """Rough proxy for 'is a plant actually in frame': fraction of pixels
    that fall in a broad green/yellow-green hue range (covers healthy green
    leaves as well as yellowing/chlorotic leaves, which are still leaf
    tissue, not background)."""
    hsv = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2HSV)
    lower = np.array([20, 25, 25])   # yellow-green start
    upper = np.array([95, 255, 255])  # deep green end
    mask = cv2.inRange(hsv, lower, upper)
    return float(np.count_nonzero(mask)) / mask.size


def assess_image_quality(image_path: str) -> dict:
    """Returns a dict describing whether the image should be accepted, plus
    the specific reason if rejected - map straight to the app's
    'Image unclear. Please retake the image.' message when accepted=False.
    """
    bgr_image = cv2.imread(image_path)
    if bgr_image is None:
        return {"accepted": False, "reason": "unreadable_file"}

    gray = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2GRAY)

    blur = blur_score(gray)
    brightness = brightness_score(gray)
    foliage_ratio = foliage_pixel_ratio(bgr_image)

    result = {
        "accepted": True,
        "reason": None,
        "metrics": {"blur_score": blur, "brightness": brightness, "foliage_ratio": foliage_ratio},
    }

    if blur < config.BLUR_LAPLACIAN_VAR_THRESHOLD:
        result["accepted"] = False
        result["reason"] = "blurry"
    elif brightness < config.MIN_MEAN_BRIGHTNESS:
        result["accepted"] = False
        result["reason"] = "too_dark"
    elif brightness > config.MAX_MEAN_BRIGHTNESS:
        result["accepted"] = False
        result["reason"] = "overexposed"
    elif foliage_ratio < config.MIN_FOLIAGE_PIXEL_RATIO:
        result["accepted"] = False
        result["reason"] = "no_plant_detected"

    return result


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python quality_gate.py path/to/photo.jpg
    if len(sys.argv) != 2:
        print("Usage: python quality_gate.py <image_path>")
        sys.exit(1)

    outcome = assess_image_quality(sys.argv[1])
    print(outcome)
