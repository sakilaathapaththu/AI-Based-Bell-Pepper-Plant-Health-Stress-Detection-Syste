"""
Thermal-based Bell Pepper Stress Evidence component - shared configuration.

Centralizes paths and hyperparameters so data_pipeline.py, model.py,
train.py, evaluate.py, feature_extraction.py, gradcam.py and app.py all
agree on the same values. Nothing in this file executes training - it only
defines constants.

See dataset_all/Thermal_Model_Training_Plan_and_Dataset_Analysis.txt for
the full reasoning behind these choices - especially Section 2 (these are
pseudo-color visual thermal images, NOT radiometric temperature data, so
"thermal_metrics" extracted here are a pixel-intensity PROXY unless/until
real radiometric calibration is obtained).
"""

from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

# Source images: Thermal-stress-evidence-identify/dataset/<ClassName>/*.png
# Classes are discovered dynamically from folder names at run time (see
# data_pipeline.discover_classes).
DATA_DIR = BASE_DIR / "dataset"

ARTIFACT_DIR = BASE_DIR / "model"
SPLITS_DIR = BASE_DIR / "splits"
REPORTS_DIR = BASE_DIR / "reports"
FEATURES_DIR = BASE_DIR / "features"

RANDOM_SEED = 42

# Source images are already uniform at 320x240 (width x height) - keep that
# native resolution rather than up/downscaling, to avoid introducing a new
# source of shortcut-learning risk. tf.image.resize takes (height, width).
IMAGE_SIZE = (240, 320)
CHANNELS = 3

HEALTHY_CLASS_NAME = "Healthy"

# Near-duplicate detection (perceptual hash). No plant/session IDs are
# provided in this dataset (see analysis doc Section 1/5), so this is used
# as a practical stand-in to avoid splitting near-identical frames across
# train/validation/test.
PHASH_SIZE = 8
NEAR_DUPLICATE_MAX_DISTANCE = 4

# Stratified, group-aware split ratios (must sum to 1.0).
TRAIN_RATIO = 0.70
VAL_RATIO = 0.15
TEST_RATIO = 0.15

# The whole dataset is modest (500 images total, 125/class) - evaluate.py
# always additionally reports stratified k-fold metrics rather than relying
# on a single small test split, regardless of per-class threshold.
KFOLD_SPLITS = 5

BATCH_SIZE = 16

# Two-phase fine-tuning schedule (see analysis doc - same transfer-learning
# playbook as the RGB component).
HEAD_TRAINING_EPOCHS = 15
HEAD_TRAINING_LR = 1e-3
FINE_TUNE_EPOCHS = 30
FINE_TUNE_LR = 1e-5
FINE_TUNE_UNFREEZE_LAST_N_LAYERS = 40

LABEL_SMOOTHING = 0.05
DROPOUT_RATE = 0.3
WEIGHT_DECAY = 1e-4

# Backbone choice - same rationale as the RGB component (server-side
# pipeline receiving uploaded/replayed thermal frames).
BACKBONE = "efficientnetb0"  # one of: efficientnetb0, mobilenetv3small

# Classes are already balanced (125/125/125/125) so heavy imbalance-fighting
# machinery (focal loss, aggressive class weighting) is NOT needed here,
# unlike the RGB component - mild class weighting is still applied as a
# safety net in case Water_Deficit-style folders are added unevenly later.
USE_FOCAL_LOSS = False
FOCAL_LOSS_GAMMA = 2.0

EARLY_STOPPING_PATIENCE = 8
REDUCE_LR_PATIENCE = 4

# Image-quality gate thresholds (classical CV - see analysis doc Section 4,
# step 1). Thermal-specific failure mode: a stuck/saturated sensor reads as
# a near-uniform color block (very low pixel variance), which is a
# different signature than an RGB photo just being "dark". These starting
# thresholds must be re-tuned against deliberately bad thermal captures,
# since the curated dataset contains only already-good frames.
BLUR_LAPLACIAN_VAR_THRESHOLD = 50.0
MIN_PIXEL_STD = 8.0  # below this, the frame is likely a flat/stuck sensor reading

# Feature extraction (Track B - see analysis doc Section 3). Foreground
# (plant-region) vs background separation uses Otsu's threshold over
# non-zero pixels as a placeholder heuristic (see
# feature_extraction.segment_plant_region for why a plain percentile
# threshold does not work on this dataset) - re-validate visually per
# analysis doc Section 6, item 3, and replace with a trained segmentation
# model if this heuristic does not hold up.

# If the plant-region proxy mean and background proxy mean differ by less
# than this, the temperature pattern isn't localized to the plant - flag
# "possible_environmental_confound" in app.py's output rather than a clean
# stress classification (analysis doc Section 4, step 6). Starting value
# only - re-tune once real sample frames with known ambient conditions are
# available.
ENV_CONFOUND_DIFF_THRESHOLD = 5.0
