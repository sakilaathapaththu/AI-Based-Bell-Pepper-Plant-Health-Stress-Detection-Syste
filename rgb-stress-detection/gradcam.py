"""
Grad-CAM sanity check.

See dataset_all/RGB_Model_Training_Plan_and_Dataset_Analysis.txt Section
3.2 and 6.3: because each class in this dataset came from a different
source/resolution pipeline, the model could learn to recognize the SOURCE
(background, compression artifacts, borders) instead of real leaf symptoms.
Grad-CAM visualizes which pixels the model actually used for its decision -
if the highlighted region is not the leaf/lesion area, the reported
accuracy should not be trusted.

This file only DEFINES functions. Nothing runs on import. To generate
Grad-CAM overlays for a sample of images, run:

    python gradcam.py

which writes overlay PNGs to reports/gradcam/.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf
from PIL import Image

import config
import data_pipeline
import model  # noqa: F401 - import registers the custom preprocessing functions with Keras before load_model() is called


def _get_backbone_layer(model: tf.keras.Model) -> tf.keras.layers.Layer:
    """Returns the nested pretrained-backbone sub-model (e.g. EfficientNetB0)
    inside the outer classification model built by model.py."""
    for layer in model.layers:
        if hasattr(layer, "layers") and layer.layers:
            return layer
    raise ValueError("Could not find a nested backbone layer in this model.")


def _last_conv_layer_name(backbone: tf.keras.Model) -> str:
    """Keras 3 removed `layer.output_shape` - use `layer.output.shape`
    instead, guarded because InputLayer/merge layers can raise when a
    layer's output tensor isn't uniquely defined."""
    for layer in reversed(backbone.layers):
        try:
            shape = layer.output.shape
        except Exception:
            continue
        if shape is not None and len(shape) == 4:
            return layer.name
    raise ValueError("Could not find a 4D (conv) layer inside the backbone for Grad-CAM.")


def make_gradcam_heatmap(image_batch: np.ndarray, model: tf.keras.Model, class_index: int) -> np.ndarray:
    """Grad-CAM for a model whose backbone is a NESTED sub-model (as built by
    model.build_model / model.build_binary_stage_model). The backbone's
    internal conv activations aren't directly reachable from the outer
    model's graph, so the forward pass is rebuilt in three pieces:
    preprocessing -> backbone (traced separately to expose the conv layer)
    -> classification head - all inside one GradientTape so gradients flow
    from the predicted class score back to the conv activations.
    """
    backbone = _get_backbone_layer(model)
    last_conv_name = _last_conv_layer_name(backbone)

    preproc_model = tf.keras.Model(model.input, model.get_layer("backbone_preprocess").output)
    conv_submodel = tf.keras.Model(backbone.input, [backbone.get_layer(last_conv_name).output, backbone.output])

    post_backbone_layers = []
    seen_backbone = False
    for layer in model.layers:
        if layer is backbone:
            seen_backbone = True
            continue
        if seen_backbone:
            post_backbone_layers.append(layer)

    preprocessed = preproc_model(image_batch, training=False)

    with tf.GradientTape() as tape:
        conv_output, backbone_output = conv_submodel(preprocessed, training=False)
        tape.watch(conv_output)
        x = backbone_output
        for layer in post_backbone_layers:
            x = layer(x, training=False)
        loss = x[:, class_index]

    grads = tape.gradient(loss, conv_output)
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))

    conv_output = conv_output[0]
    heatmap = conv_output @ pooled_grads[..., tf.newaxis]
    heatmap = tf.squeeze(heatmap)
    heatmap = tf.maximum(heatmap, 0) / (tf.reduce_max(heatmap) + 1e-8)
    return heatmap.numpy()


def overlay_heatmap(original_image: np.ndarray, heatmap: np.ndarray, alpha: float = 0.4) -> Image.Image:
    heatmap_img = Image.fromarray(np.uint8(255 * heatmap)).resize(
        (original_image.shape[1], original_image.shape[0])
    )
    heatmap_colored = np.array(heatmap_img.convert("L"))
    heatmap_rgb = np.stack(
        [heatmap_colored, np.zeros_like(heatmap_colored), 255 - heatmap_colored], axis=-1
    )

    base = np.uint8(original_image * 255) if original_image.max() <= 1.0 else np.uint8(original_image)
    blended = np.uint8(base * (1 - alpha) + heatmap_rgb * alpha)
    return Image.fromarray(blended)


def run(samples_per_class: int = 3) -> None:
    manifest = pd.read_csv(config.SPLITS_DIR / "manifest.csv")
    metadata = json.loads((config.ARTIFACT_DIR / "model_metadata.json").read_text())

    if metadata["training_mode"] == "two_stage_cascade":
        class_names = metadata["stage2_class_names"]
        model = tf.keras.models.load_model(config.ARTIFACT_DIR / "stage2_final.keras", compile=False)
        eval_df = manifest[(manifest["split"] == "test") & (manifest["class"] != config.HEALTHY_CLASS_NAME)]
    else:
        class_names = metadata["flat_class_names"]
        model = tf.keras.models.load_model(config.ARTIFACT_DIR / "flat_model_final.keras", compile=False)
        eval_df = manifest[manifest["split"] == "test"]

    out_dir = config.REPORTS_DIR / "gradcam"
    out_dir.mkdir(parents=True, exist_ok=True)

    for class_name in class_names:
        class_index = class_names.index(class_name)
        class_samples = eval_df[eval_df["class"] == class_name].head(samples_per_class)

        for _, row in class_samples.iterrows():
            path_tensor = tf.constant(row["filepath"])
            label_tensor = tf.constant(class_index)
            image, _ = data_pipeline.load_and_preprocess(path_tensor, label_tensor, training=False)
            image_np = image.numpy()
            batch = np.expand_dims(image_np, axis=0)

            heatmap = make_gradcam_heatmap(batch, model, class_index)
            overlay = overlay_heatmap(image_np, heatmap)

            out_path = out_dir / f"{class_name}_{Path(row['filepath']).stem}.png"
            overlay.save(out_path)
            print(f"[gradcam] Saved {out_path}")


if __name__ == "__main__":
    # Deliberately not invoked automatically - run manually with:
    #   python gradcam.py
    run()
