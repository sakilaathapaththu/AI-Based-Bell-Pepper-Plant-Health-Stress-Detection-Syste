"""
RGB Bell Pepper Stress Detection - shared configuration.

Centralizes paths and hyperparameters so data_pipeline.py, model.py,
train.py, evaluate.py and gradcam.py all agree on the same values.
Nothing in this file executes training - it only defines constants.
"""

from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent

# Source images: rgb-stress-detection/dataset/<ClassName>/*.jpg
# Classes are discovered dynamically from folder names at run time (see
# data_pipeline.discover_classes) so adding Water_Deficit later requires no
# code change here - just drop images into dataset/Water_Deficit/ and
# retrain. This folder was seeded from
# dataset_all/RGB_BellPepper_Developer_Master_Handoff/data (Healthy,
# Nutrient_Deficiency, Aphid, Thrips already copied in); Water_Deficit
# starts empty until you add images.
DATA_DIR = BASE_DIR / "dataset"

ARTIFACT_DIR = BASE_DIR / "model"
SPLITS_DIR = BASE_DIR / "splits"
REPORTS_DIR = BASE_DIR / "reports"

RANDOM_SEED = 42

# Standardized preprocessing target size. Fixed regardless of each class's
# original resolution (256x256 / 1000x1000 / variable) - this is required to
# avoid the model learning per-source resolution/compression shortcuts
# instead of real leaf symptoms (see dataset_all analysis doc, Section 3.2
# and 4.4).
IMAGE_SIZE = (256, 256)
CHANNELS = 3

# Near-duplicate detection (perceptual hash). Images whose hash differs by
# <= this Hamming distance are treated as the same "group" and are forced
# into the same split to avoid leakage between train/val/test.
PHASH_SIZE = 8
NEAR_DUPLICATE_MAX_DISTANCE = 4

# Stratified, group-aware split ratios (must sum to 1.0).
TRAIN_RATIO = 0.70
VAL_RATIO = 0.15
TEST_RATIO = 0.15

# For classes with fewer than this many images, evaluate.py additionally
# reports stratified k-fold metrics instead of relying on the single small
# test split (see analysis doc Section 4.5 - Aphid/Thrips are this small).
SMALL_CLASS_THRESHOLD = 100
KFOLD_SPLITS = 5

BATCH_SIZE = 32

# Two-phase fine-tuning schedule (see analysis doc Section 4.8).
HEAD_TRAINING_EPOCHS = 15
HEAD_TRAINING_LR = 1e-3
FINE_TUNE_EPOCHS = 40
FINE_TUNE_LR = 1e-5
FINE_TUNE_UNFREEZE_LAST_N_LAYERS = 40

LABEL_SMOOTHING = 0.08
DROPOUT_RATE = 0.3
WEIGHT_DECAY = 1e-4

# Backbone choice. "efficientnetb0" is the primary recommendation for a
# server-side/API pipeline (matches the described architecture where the
# app uploads a photo and the backend resizes/normalizes/analyzes it).
# "mobilenetv3small" is the fallback for an on-device / offline export.
BACKBONE = "efficientnetb0"  # one of: efficientnetb0, mobilenetv3small

USE_FOCAL_LOSS = True
FOCAL_LOSS_GAMMA = 2.0

# Two-stage cascade (Healthy vs Stressed, then stress-type-among-stressed).
# See analysis doc Section 4.1. Set to False to train a single flat
# N-class classifier instead.
USE_TWO_STAGE_CASCADE = True
HEALTHY_CLASS_NAME = "Healthy"

EARLY_STOPPING_PATIENCE = 8
REDUCE_LR_PATIENCE = 4

# Image-quality gate thresholds (classical CV, not the deep model - see
# analysis doc Section 4.2). These are starting points only: they must be
# re-tuned against a self-collected sample of deliberately blurry/dark/
# miscomposed phone photos, since the curated dataset contains only
# already-good images and cannot be used to tune this gate.
BLUR_LAPLACIAN_VAR_THRESHOLD = 100.0
MIN_MEAN_BRIGHTNESS = 40.0
MAX_MEAN_BRIGHTNESS = 220.0
MIN_FOLIAGE_PIXEL_RATIO = 0.05
