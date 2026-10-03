"""
Thermal-based Bell Pepper Stress Evidence - Track A training pipeline
(end-to-end CNN image classifier).

Follows dataset_all/Thermal_Model_Training_Plan_and_Dataset_Analysis.txt:
    1. Build a leakage-safe, group-aware, class-stratified split.
    2. Train a flat 4-class classifier (Healthy / Heat_Stress /
       Nutrient_Stress / Water_Stress) - classes are already balanced, so no
       two-stage cascade or focal loss is needed here (unlike the RGB
       component).
    3. Transfer learning: frozen-backbone phase, then fine-tuning phase.
    4. Save artifacts (model, metadata) to model/.

This file only DEFINES the pipeline. Nothing runs on import. To actually
train, run:

    python train.py

Track B (feature-based classical ML model) is trained separately:

    python feature_extraction.py

Evaluation and Grad-CAM sanity checks for Track A are in evaluate.py /
gradcam.py, run separately after training:

    python evaluate.py
    python gradcam.py
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

import tensorflow as tf

import config
import data_pipeline
import model as model_lib


def _compile_model(model: tf.keras.Model, learning_rate: float) -> None:
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss=tf.keras.losses.CategoricalCrossentropy(label_smoothing=config.LABEL_SMOOTHING),
        metrics=[
            tf.keras.metrics.CategoricalAccuracy(name="accuracy"),
            tf.keras.metrics.AUC(name="auc", multi_label=True),
        ],
    )


def _callbacks(checkpoint_path):
    return [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(checkpoint_path), monitor="val_loss", save_best_only=True, save_weights_only=False
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=config.EARLY_STOPPING_PATIENCE, restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=config.REDUCE_LR_PATIENCE, min_lr=1e-7
        ),
    ]


def train_flat_model(data: dict) -> tf.keras.Model:
    class_names = data["class_names"]
    num_classes = len(class_names)

    model = model_lib.build_model(num_classes)
    _compile_model(model, config.HEAD_TRAINING_LR)

    config.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"[train] Phase 1: training classification head only ({config.HEAD_TRAINING_EPOCHS} epochs)")
    model.fit(
        data["train_ds"],
        validation_data=data["val_ds"],
        epochs=config.HEAD_TRAINING_EPOCHS,
        class_weight=data["class_weights"] if config.USE_FOCAL_LOSS else None,
        callbacks=_callbacks(config.ARTIFACT_DIR / "track_a_phase1.keras"),
    )

    print(f"[train] Phase 2: fine-tuning top layers ({config.FINE_TUNE_EPOCHS} epochs)")
    model_lib.unfreeze_top_layers(model)
    _compile_model(model, config.FINE_TUNE_LR)
    model.fit(
        data["train_ds"],
        validation_data=data["val_ds"],
        epochs=config.FINE_TUNE_EPOCHS,
        class_weight=data["class_weights"] if config.USE_FOCAL_LOSS else None,
        callbacks=_callbacks(config.ARTIFACT_DIR / "track_a_final.keras"),
    )

    return model


def save_metadata(class_names: list[str]) -> None:
    metadata = {
        "model_version": "thermal-bellpepper-stress-v1",
        "training_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "training_mode": "flat",
        "flat_class_names": class_names,
        "healthy_class_name": config.HEALTHY_CLASS_NAME,
        "image_size": list(config.IMAGE_SIZE),
        "backbone": config.BACKBONE,
        "thermal_metrics_basis": "pixel_intensity_proxy",
        "notes": (
            "Trained on pseudo-color visual thermal images with no radiometric "
            "calibration metadata - see "
            "dataset_all/Thermal_Model_Training_Plan_and_Dataset_Analysis.txt "
            "Section 2 before reporting any thermal_metrics as calibrated "
            "degrees Celsius. Dataset authenticity (real camera vs simulated) "
            "is unconfirmed - see Section 1."
        ),
    }
    config.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    (config.ARTIFACT_DIR / "model_metadata.json").write_text(json.dumps(metadata, indent=2))


def run() -> None:
    manifest = data_pipeline.build_manifest(save=True)
    print("Split sizes per class:")
    print(manifest.groupby(["class", "split"]).size())

    data = data_pipeline.load_split_datasets(manifest)
    train_flat_model(data)
    save_metadata(class_names=data["class_names"])
    print(f"[train] Done. Track A artifacts saved to {config.ARTIFACT_DIR}")
    print("[train] Next: run 'python feature_extraction.py' to also train Track B.")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python train.py
    run()
