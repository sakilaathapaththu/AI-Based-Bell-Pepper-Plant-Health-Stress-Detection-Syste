"""
RGB Bell Pepper Stress Detection - training pipeline.

Follows the methodology in
dataset_all/RGB_Model_Training_Plan_and_Dataset_Analysis.txt:
    1. Build a leakage-safe, group-aware, class-stratified split.
    2. Train either a flat N-class classifier or a two-stage cascade
       (Healthy-vs-Stressed, then stress-type-among-stressed).
    3. Transfer learning with a frozen-backbone phase then a fine-tuning
       phase.
    4. Class-weighted focal loss to fight the severe class imbalance.
    5. Save all artifacts (model, class index, metadata) to model/.

This file only DEFINES the pipeline. Nothing runs on import. To actually
train, run:

    python train.py

Evaluation (macro-F1, confusion matrix, calibration, Grad-CAM sanity
checks) is intentionally kept in evaluate.py / gradcam.py, run separately
after training:

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
from losses import categorical_focal_loss


def _compile_flat_model(model: tf.keras.Model, learning_rate: float) -> None:
    loss = (
        categorical_focal_loss(gamma=config.FOCAL_LOSS_GAMMA, label_smoothing=config.LABEL_SMOOTHING)
        if config.USE_FOCAL_LOSS
        else tf.keras.losses.CategoricalCrossentropy(label_smoothing=config.LABEL_SMOOTHING)
    )
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss=loss,
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
    _compile_flat_model(model, config.HEAD_TRAINING_LR)

    print(f"[train] Phase 1: training classification head only ({config.HEAD_TRAINING_EPOCHS} epochs)")
    config.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    phase1_ckpt = config.ARTIFACT_DIR / "flat_model_phase1.keras"
    model.fit(
        data["train_ds"],
        validation_data=data["val_ds"],
        epochs=config.HEAD_TRAINING_EPOCHS,
        class_weight=data["class_weights"],
        callbacks=_callbacks(phase1_ckpt),
    )

    print(f"[train] Phase 2: fine-tuning top layers ({config.FINE_TUNE_EPOCHS} epochs)")
    model_lib.unfreeze_top_layers(model)
    _compile_flat_model(model, config.FINE_TUNE_LR)
    phase2_ckpt = config.ARTIFACT_DIR / "flat_model_final.keras"
    model.fit(
        data["train_ds"],
        validation_data=data["val_ds"],
        epochs=config.FINE_TUNE_EPOCHS,
        class_weight=data["class_weights"],
        callbacks=_callbacks(phase2_ckpt),
    )

    return model


def _filter_binary_labels(manifest, healthy_class: str):
    """Maps every row's class to a binary label: 0 = Healthy, 1 = Stressed."""
    df = manifest.copy()
    df["binary_label"] = (df["class"] != healthy_class).astype(int)
    return df


def train_stage1_binary(manifest) -> tf.keras.Model:
    df = _filter_binary_labels(manifest, config.HEALTHY_CLASS_NAME)

    def make_binary_ds(split_name: str, training: bool):
        split_df = df[df["split"] == split_name]
        paths = split_df["filepath"].tolist()
        labels = split_df["binary_label"].tolist()
        ds = tf.data.Dataset.from_tensor_slices((paths, labels))
        if training:
            ds = ds.shuffle(min(len(split_df), 4096), seed=config.RANDOM_SEED)
        ds = ds.map(
            lambda p, l: data_pipeline.load_and_preprocess(p, l, training=training),
            num_parallel_calls=tf.data.AUTOTUNE,
        )
        ds = ds.map(lambda img, lbl: (img, tf.cast(lbl, tf.float32)), num_parallel_calls=tf.data.AUTOTUNE)
        return ds.batch(config.BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

    train_ds = make_binary_ds("train", training=True)
    val_ds = make_binary_ds("validation", training=False)

    healthy_count = (df[df["split"] == "train"]["binary_label"] == 0).sum()
    stressed_count = (df[df["split"] == "train"]["binary_label"] == 1).sum()
    total = healthy_count + stressed_count
    class_weight = {
        0: total / (2 * max(healthy_count, 1)),
        1: total / (2 * max(stressed_count, 1)),
    }

    model = model_lib.build_binary_stage_model()
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=config.HEAD_TRAINING_LR),
        loss=tf.keras.losses.BinaryCrossentropy(label_smoothing=config.LABEL_SMOOTHING),
        metrics=[tf.keras.metrics.BinaryAccuracy(name="accuracy"), tf.keras.metrics.AUC(name="auc")],
    )

    config.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    print("[train] Stage 1 (Healthy vs Stressed) - phase 1: head only")
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=config.HEAD_TRAINING_EPOCHS,
        class_weight=class_weight,
        callbacks=_callbacks(config.ARTIFACT_DIR / "stage1_phase1.keras"),
    )

    model_lib.unfreeze_top_layers(model)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=config.FINE_TUNE_LR),
        loss=tf.keras.losses.BinaryCrossentropy(label_smoothing=config.LABEL_SMOOTHING),
        metrics=[tf.keras.metrics.BinaryAccuracy(name="accuracy"), tf.keras.metrics.AUC(name="auc")],
    )
    print("[train] Stage 1 (Healthy vs Stressed) - phase 2: fine-tune")
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=config.FINE_TUNE_EPOCHS,
        class_weight=class_weight,
        callbacks=_callbacks(config.ARTIFACT_DIR / "stage1_final.keras"),
    )
    return model


def train_stage2_stress_type(manifest) -> tuple[tf.keras.Model, list[str]]:
    """Stage 2 of the cascade: classify WHICH stress/cause among the
    non-Healthy classes only. Trained purely on stressed samples so class
    balancing isn't diluted by the large Healthy class (analysis doc
    Section 4.1)."""
    stressed_df = manifest[manifest["class"] != config.HEALTHY_CLASS_NAME].copy()
    class_names = sorted(stressed_df["class"].unique().tolist())

    train_df = stressed_df[stressed_df["split"] == "train"]
    val_df = stressed_df[stressed_df["split"] == "validation"]

    train_ds = data_pipeline.make_dataset(train_df, class_names, training=True)
    val_ds = data_pipeline.make_dataset(val_df, class_names, training=False)
    class_weights = data_pipeline.compute_class_weights(train_df, class_names)

    model = model_lib.build_model(num_classes=len(class_names))
    _compile_flat_model(model, config.HEAD_TRAINING_LR)

    config.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[train] Stage 2 (stress type among {class_names}) - phase 1: head only")
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=config.HEAD_TRAINING_EPOCHS,
        class_weight=class_weights,
        callbacks=_callbacks(config.ARTIFACT_DIR / "stage2_phase1.keras"),
    )

    model_lib.unfreeze_top_layers(model)
    _compile_flat_model(model, config.FINE_TUNE_LR)
    print("[train] Stage 2 - phase 2: fine-tune")
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=config.FINE_TUNE_EPOCHS,
        class_weight=class_weights,
        callbacks=_callbacks(config.ARTIFACT_DIR / "stage2_final.keras"),
    )
    return model, class_names


def save_metadata(class_names: list[str], mode: str, stage2_class_names: list[str] | None = None) -> None:
    metadata = {
        "model_version": "rgb-bellpepper-stress-v1",
        "training_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "training_mode": mode,  # "flat" or "two_stage_cascade"
        "flat_class_names": class_names,
        "stage2_class_names": stage2_class_names,
        "image_size": list(config.IMAGE_SIZE),
        "backbone": config.BACKBONE,
        "notes": (
            "Water_Deficit and Heat Stress may be absent from flat_class_names "
            "if those folders had zero images at training time - see "
            "dataset_all/RGB_Model_Training_Plan_and_Dataset_Analysis.txt "
            "Section 2 before reporting results against the originally "
            "planned class list."
        ),
    }
    config.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    (config.ARTIFACT_DIR / "model_metadata.json").write_text(json.dumps(metadata, indent=2))


def run() -> None:
    manifest = data_pipeline.build_manifest(save=True)
    print("Split sizes per class:")
    print(manifest.groupby(["class", "split"]).size())

    if config.USE_TWO_STAGE_CASCADE:
        stage1_model = train_stage1_binary(manifest)
        stage2_model, stage2_classes = train_stage2_stress_type(manifest)
        save_metadata(class_names=[config.HEALTHY_CLASS_NAME], mode="two_stage_cascade", stage2_class_names=stage2_classes)
        print(f"[train] Done. Artifacts saved to {config.ARTIFACT_DIR}")
    else:
        data = data_pipeline.load_split_datasets(manifest)
        flat_model = train_flat_model(data)
        save_metadata(class_names=data["class_names"], mode="flat")
        print(f"[train] Done. Artifacts saved to {config.ARTIFACT_DIR}")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python train.py
    run()
