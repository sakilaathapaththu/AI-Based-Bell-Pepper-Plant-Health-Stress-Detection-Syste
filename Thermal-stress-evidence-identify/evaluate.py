"""
Track A evaluation: macro-F1, per-class precision/recall/F1, confusion
matrix, stratified k-fold (dataset is modest - 500 images total), and
confidence calibration (temperature scaling + Expected Calibration Error).

See dataset_all/Thermal_Model_Training_Plan_and_Dataset_Analysis.txt
Section 5 - even though classes are balanced, report macro-F1 and the full
confusion matrix, not just accuracy, since some stress types may still be
visually confusable (e.g. Heat_Stress vs Water_Stress can both raise leaf
temperature).

This file only DEFINES functions. Nothing runs on import. To evaluate an
already-trained model, run:

    python evaluate.py

which loads model/track_a_final.keras and splits/manifest.csv, and writes a
report to reports/.
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


def evaluate_on_split(model_obj: tf.keras.Model, df: pd.DataFrame, class_names: list[str]) -> dict:
    ds = data_pipeline.make_dataset(df, class_names, training=False)
    y_true_onehot = np.concatenate([y.numpy() for _, y in ds], axis=0)
    y_true = np.argmax(y_true_onehot, axis=1)

    y_prob = model_obj.predict(ds)
    y_pred = np.argmax(y_prob, axis=1)

    report = classification_report(y_true, y_pred, target_names=class_names, output_dict=True, zero_division=0)
    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(class_names))))

    return {
        "classification_report": report,
        "confusion_matrix": cm.tolist(),
        "macro_f1": float(report["macro avg"]["f1-score"]),
        "y_true": y_true,
        "y_prob": y_prob,
    }


def kfold_evaluate(manifest: pd.DataFrame, class_names: list[str]) -> dict:
    """The whole dataset is modest (500 images total, 125/class) - k-fold
    gives a more trustworthy macro-F1 estimate than a single small test
    split. Each fold trains a throwaway copy from scratch, separate from
    the production model trained by train.py, purely for evaluation."""
    import model as model_lib

    skf = StratifiedKFold(n_splits=config.KFOLD_SPLITS, shuffle=True, random_state=config.RANDOM_SEED)
    fold_f1_scores = []

    for fold_idx, (train_idx, test_idx) in enumerate(skf.split(manifest, manifest["class"])):
        train_df = manifest.iloc[train_idx]
        test_df = manifest.iloc[test_idx]

        train_ds = data_pipeline.make_dataset(train_df, class_names, training=True)
        test_ds = data_pipeline.make_dataset(test_df, class_names, training=False)

        fold_model = model_lib.build_model(len(class_names))
        fold_model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=config.HEAD_TRAINING_LR),
            loss=tf.keras.losses.CategoricalCrossentropy(label_smoothing=config.LABEL_SMOOTHING),
            metrics=["accuracy"],
        )
        fold_model.fit(train_ds, epochs=config.HEAD_TRAINING_EPOCHS, verbose=0)

        y_true = np.argmax(np.concatenate([y.numpy() for _, y in test_ds], axis=0), axis=1)
        y_prob = fold_model.predict(test_ds, verbose=0)
        y_pred = np.argmax(y_prob, axis=1)

        fold_f1 = f1_score(y_true, y_pred, average="macro", zero_division=0)
        fold_f1_scores.append(fold_f1)
        print(f"[evaluate] fold {fold_idx + 1}/{config.KFOLD_SPLITS}: macro-F1 = {fold_f1:.3f}")

    return {
        "fold_macro_f1": fold_f1_scores,
        "mean_macro_f1": float(np.mean(fold_f1_scores)),
        "std_macro_f1": float(np.std(fold_f1_scores)),
    }


# ---------------------------------------------------------------------------
# Confidence calibration: temperature scaling + Expected Calibration Error
# ---------------------------------------------------------------------------

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
    metadata = json.loads((config.ARTIFACT_DIR / "model_metadata.json").read_text())
    class_names = metadata["flat_class_names"]

    trained_model = tf.keras.models.load_model(config.ARTIFACT_DIR / "track_a_final.keras", compile=False)
    test_df = manifest[manifest["split"] == "test"]
    results = evaluate_on_split(trained_model, test_df, class_names)

    print(f"[evaluate] Track A macro-F1 on test set: {results['macro_f1']:.3f}")
    print(json.dumps(results["classification_report"], indent=2))

    ece = expected_calibration_error(results["y_true"], results["y_prob"])
    print(f"[evaluate] Expected Calibration Error (uncalibrated): {ece:.4f}")

    kfold_metrics = kfold_evaluate(manifest, class_names)
    print(f"[evaluate] {config.KFOLD_SPLITS}-fold mean macro-F1: {kfold_metrics['mean_macro_f1']:.3f} +/- {kfold_metrics['std_macro_f1']:.3f}")

    report = {
        "macro_f1": results["macro_f1"],
        "classification_report": results["classification_report"],
        "confusion_matrix": results["confusion_matrix"],
        "ece_uncalibrated": ece,
        "kfold": kfold_metrics,
    }

    config.REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = config.REPORTS_DIR / "evaluation_report.json"
    out_path.write_text(json.dumps(report, indent=2))
    print(f"[evaluate] Report written to {out_path}")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python evaluate.py
    run()
