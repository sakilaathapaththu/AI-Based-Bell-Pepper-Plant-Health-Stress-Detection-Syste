"""
Evaluation: macro-F1, per-class precision/recall/F1, confusion matrix,
stratified k-fold for small classes, and confidence calibration
(temperature scaling + Expected Calibration Error).

See dataset_all/RGB_Model_Training_Plan_and_Dataset_Analysis.txt Section 6
("how to prove good accuracy honestly") - raw accuracy alone is explicitly
NOT trusted in this project because of severe class imbalance.

This file only DEFINES functions. Nothing runs on import. To evaluate an
already-trained model, run:

    python evaluate.py

which loads model/flat_model_final.keras (or the stage1/stage2 cascade
models) and splits/manifest.csv, and writes a report to reports/.
"""

from __future__ import annotations

import json

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import StratifiedKFold

import config
import data_pipeline
import model  # noqa: F401 - import registers the custom preprocessing functions with Keras before load_model() is called


def evaluate_on_split(model: tf.keras.Model, df: pd.DataFrame, class_names: list[str]) -> dict:
    ds = data_pipeline.make_dataset(df, class_names, training=False)
    y_true_onehot = np.concatenate([y.numpy() for _, y in ds], axis=0)
    y_true = np.argmax(y_true_onehot, axis=1)

    y_prob = model.predict(ds)
    y_pred = np.argmax(y_prob, axis=1)

    report = classification_report(
        y_true, y_pred, target_names=class_names, output_dict=True, zero_division=0
    )
    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(class_names))))

    return {
        "classification_report": report,
        "confusion_matrix": cm.tolist(),
        "macro_f1": float(report["macro avg"]["f1-score"]),
        "y_true": y_true,
        "y_pred": y_pred,
        "y_prob": y_prob,
    }


def kfold_evaluate_small_classes(manifest: pd.DataFrame, model_builder, class_names: list[str]) -> dict:
    """For classes below config.SMALL_CLASS_THRESHOLD, a single 15% test
    split has too few images to be statistically reliable (see analysis doc
    Section 4.5, Aphid=24 / Thrips=57). This runs stratified k-fold purely
    for evaluation purposes and reports mean +/- std macro-F1.

    model_builder: a zero-arg callable that returns a freshly-compiled,
    untrained model (e.g. lambda: model.build_model(len(class_names))).
    Each fold trains a throwaway copy from scratch - this is deliberately
    separate from (and more expensive than) the single production model
    trained by train.py, and exists only to produce trustworthy metrics.
    """
    counts = manifest["class"].value_counts()
    small_classes = [c for c in class_names if counts.get(c, 0) < config.SMALL_CLASS_THRESHOLD]
    if not small_classes:
        print("[evaluate] No small classes below threshold; skipping k-fold evaluation.")
        return {}

    print(f"[evaluate] Running {config.KFOLD_SPLITS}-fold evaluation for small classes: {small_classes}")
    subset = manifest[manifest["class"].isin(small_classes)].reset_index(drop=True)

    skf = StratifiedKFold(n_splits=config.KFOLD_SPLITS, shuffle=True, random_state=config.RANDOM_SEED)
    fold_f1_scores = []

    for fold_idx, (train_idx, test_idx) in enumerate(skf.split(subset, subset["class"])):
        train_df = subset.iloc[train_idx]
        test_df = subset.iloc[test_idx]

        train_ds = data_pipeline.make_dataset(train_df, small_classes, training=True)
        test_ds = data_pipeline.make_dataset(test_df, small_classes, training=False)

        fold_model = model_builder()
        fold_model.fit(train_ds, epochs=config.HEAD_TRAINING_EPOCHS, verbose=0)

        y_true = np.argmax(np.concatenate([y.numpy() for _, y in test_ds], axis=0), axis=1)
        y_prob = fold_model.predict(test_ds, verbose=0)
        y_pred = np.argmax(y_prob, axis=1)

        fold_f1 = f1_score(y_true, y_pred, average="macro", zero_division=0)
        fold_f1_scores.append(fold_f1)
        print(f"[evaluate] fold {fold_idx + 1}/{config.KFOLD_SPLITS}: macro-F1 = {fold_f1:.3f}")

    return {
        "small_classes": small_classes,
        "fold_macro_f1": fold_f1_scores,
        "mean_macro_f1": float(np.mean(fold_f1_scores)),
        "std_macro_f1": float(np.std(fold_f1_scores)),
    }


# ---------------------------------------------------------------------------
# Confidence calibration: temperature scaling + Expected Calibration Error
# See analysis doc Section 5.2 - "89% confidence" should mean the model is
# actually correct ~89% of the time, which raw softmax usually is NOT.
# ---------------------------------------------------------------------------

def fit_temperature(logits: np.ndarray, y_true: np.ndarray, max_iter: int = 200) -> float:
    """Fits a single scalar temperature T minimizing NLL of softmax(logits / T)
    on a held-out (validation) set, via simple gradient descent."""
    temperature = tf.Variable(1.0, dtype=tf.float32)
    logits_t = tf.constant(logits, dtype=tf.float32)
    labels_t = tf.constant(y_true, dtype=tf.int32)
    optimizer = tf.keras.optimizers.Adam(learning_rate=0.01)

    for _ in range(max_iter):
        with tf.GradientTape() as tape:
            scaled = logits_t / temperature
            loss = tf.keras.losses.sparse_categorical_crossentropy(labels_t, scaled, from_logits=True)
            loss = tf.reduce_mean(loss)
        grads = tape.gradient(loss, [temperature])
        optimizer.apply_gradients(zip(grads, [temperature]))
        temperature.assign(tf.maximum(temperature, 1e-3))

    return float(temperature.numpy())


def expected_calibration_error(y_true: np.ndarray, y_prob: np.ndarray, n_bins: int = 15) -> float:
    confidences = np.max(y_prob, axis=1)
    predictions = np.argmax(y_prob, axis=1)
    accuracies = (predictions == y_true).astype(np.float32)

    bin_edges = np.linspace(0.0, 1.0, n_bins + 1)
    ece = 0.0
    n = len(y_true)

    for lo, hi in zip(bin_edges[:-1], bin_edges[1:]):
        mask = (confidences > lo) & (confidences <= hi)
        if not np.any(mask):
            continue
        bin_acc = accuracies[mask].mean()
        bin_conf = confidences[mask].mean()
        ece += (mask.sum() / n) * abs(bin_acc - bin_conf)

    return float(ece)


def run() -> None:
    manifest = pd.read_csv(config.SPLITS_DIR / "manifest.csv")

    metadata_path = config.ARTIFACT_DIR / "model_metadata.json"
    metadata = json.loads(metadata_path.read_text())

    config.REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    all_results = {}

    if metadata["training_mode"] == "two_stage_cascade":
        stage2_classes = metadata["stage2_class_names"]
        stage2_model = tf.keras.models.load_model(
            config.ARTIFACT_DIR / "stage2_final.keras", compile=False
        )
        test_df = manifest[(manifest["split"] == "test") & (manifest["class"] != config.HEALTHY_CLASS_NAME)]
        stage2_results = evaluate_on_split(stage2_model, test_df, stage2_classes)
        print(f"[evaluate] Stage 2 macro-F1 on test set: {stage2_results['macro_f1']:.3f}")
        print(json.dumps(stage2_results["classification_report"], indent=2))
        all_results["stage2"] = {
            "macro_f1": stage2_results["macro_f1"],
            "classification_report": stage2_results["classification_report"],
            "confusion_matrix": stage2_results["confusion_matrix"],
        }

        ece = expected_calibration_error(stage2_results["y_true"], stage2_results["y_prob"])
        print(f"[evaluate] Stage 2 Expected Calibration Error (uncalibrated): {ece:.4f}")
        all_results["stage2"]["ece_uncalibrated"] = ece
    else:
        class_names = metadata["flat_class_names"]
        model = tf.keras.models.load_model(config.ARTIFACT_DIR / "flat_model_final.keras", compile=False)
        test_df = manifest[manifest["split"] == "test"]
        results = evaluate_on_split(model, test_df, class_names)
        print(f"[evaluate] Flat model macro-F1 on test set: {results['macro_f1']:.3f}")
        print(json.dumps(results["classification_report"], indent=2))
        all_results["flat"] = {
            "macro_f1": results["macro_f1"],
            "classification_report": results["classification_report"],
            "confusion_matrix": results["confusion_matrix"],
        }

        ece = expected_calibration_error(results["y_true"], results["y_prob"])
        print(f"[evaluate] Expected Calibration Error (uncalibrated): {ece:.4f}")
        all_results["flat"]["ece_uncalibrated"] = ece

    out_path = config.REPORTS_DIR / "evaluation_report.json"
    out_path.write_text(json.dumps(all_results, indent=2))
    print(f"[evaluate] Report written to {out_path}")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python evaluate.py
    run()
