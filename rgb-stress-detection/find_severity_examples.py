"""
Finds real test-set images that land in each severity bucket (Mild /
Moderate / Severe), so you have concrete file paths to upload in Postman
when manually testing app.py's /predict endpoint.

Severity is derived from the model's own confidence score (see app.py's
severity_from_confidence) - it is a heuristic proxy, not a ground-truth
label - so which image ends up Mild vs Severe is data-dependent and can
only be discovered by actually running the trained model, which is what
this script does.

This file only DEFINES a function. Nothing runs on import. To find example
images, run:

    python find_severity_examples.py

which prints up to N file paths per severity bucket per stress class.
"""

from __future__ import annotations

import json

import numpy as np
import pandas as pd
import tensorflow as tf

import config
import data_pipeline
import model  # noqa: F401 - registers custom preprocessing functions before load_model()
from app import severity_from_confidence


def run(examples_per_bucket: int = 2) -> None:
    manifest = pd.read_csv(config.SPLITS_DIR / "manifest.csv")
    metadata = json.loads((config.ARTIFACT_DIR / "model_metadata.json").read_text())

    if metadata["training_mode"] != "two_stage_cascade":
        class_names = metadata["flat_class_names"]
        stage2_model = tf.keras.models.load_model(config.ARTIFACT_DIR / "flat_model_final.keras", compile=False)
        eval_df = manifest[manifest["split"] == "test"]
    else:
        class_names = metadata["stage2_class_names"]
        stage2_model = tf.keras.models.load_model(config.ARTIFACT_DIR / "stage2_final.keras", compile=False)
        eval_df = manifest[(manifest["split"] == "test") & (manifest["class"] != config.HEALTHY_CLASS_NAME)]

    buckets: dict[str, list[tuple[str, str, float]]] = {"Mild": [], "Moderate": [], "Severe": []}

    for _, row in eval_df.iterrows():
        path_tensor = tf.constant(row["filepath"])
        label_tensor = tf.constant(0)
        image, _ = data_pipeline.load_and_preprocess(path_tensor, label_tensor, training=False)
        batch = tf.expand_dims(image, axis=0)

        probs = stage2_model.predict(batch, verbose=0)[0]
        class_index = int(np.argmax(probs))
        confidence = float(probs[class_index])
        predicted_class = class_names[class_index]
        severity = severity_from_confidence(confidence)

        buckets[severity].append((row["filepath"], predicted_class, confidence))

    for severity in ["Mild", "Moderate", "Severe"]:
        print(f"\n=== {severity} (confidence range per app.py) ===")
        examples = buckets[severity][:examples_per_bucket]
        if not examples:
            print("  (no test-set image fell into this bucket yet)")
        for filepath, predicted_class, confidence in examples:
            print(f"  {filepath}  -> stress_type={predicted_class}, confidence={confidence:.4f}")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python find_severity_examples.py
    run()
