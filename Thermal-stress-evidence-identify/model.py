"""
Track A model definition: transfer-learning backbone + classification head
for the pseudo-color thermal images, with helpers to freeze/unfreeze for the
two-phase fine-tuning schedule.

A single FLAT 4-class classifier is used here (Healthy / Heat_Stress /
Nutrient_Stress / Water_Stress) rather than the RGB component's two-stage
cascade, because this dataset is already balanced (125 images/class) - see
dataset_all/Thermal_Model_Training_Plan_and_Dataset_Analysis.txt Section 5.
"Healthy vs Stressed" (plant_condition) is derived downstream from the
predicted class instead of needing its own model.

Nothing executes on import.
"""

from __future__ import annotations

import keras
import tensorflow as tf
from tensorflow.keras import layers, models

import config


# Plain functions imported from tf.keras.applications (e.g.
# efficientnet.preprocess_input) cannot be serialized/reloaded inside a
# Lambda layer by the .keras save format - loading a saved model raises
# "Could not locate function 'preprocess_input'". Wrapping each one in a
# named, registered function fixes this (same fix applied in the RGB
# component's model.py after hitting this in practice).
#
# Registered via the standalone `keras` package (Keras 3), not `tf.keras`:
# tf.keras.saving does not exist in this TensorFlow/Keras combination.
@keras.saving.register_keras_serializable(package="thermal_stress_detection", name="efficientnet_preprocess")
def _efficientnet_preprocess(x):
    return tf.keras.applications.efficientnet.preprocess_input(x)


@keras.saving.register_keras_serializable(package="thermal_stress_detection", name="mobilenetv3_preprocess")
def _mobilenetv3_preprocess(x):
    return tf.keras.applications.mobilenet_v3.preprocess_input(x)


def _build_backbone(backbone_name: str, input_shape: tuple[int, int, int]):
    if backbone_name == "efficientnetb0":
        base = tf.keras.applications.EfficientNetB0(
            include_top=False, weights="imagenet", input_shape=input_shape, pooling="avg"
        )
        preprocess = _efficientnet_preprocess
    elif backbone_name == "mobilenetv3small":
        base = tf.keras.applications.MobileNetV3Small(
            include_top=False, weights="imagenet", input_shape=input_shape, pooling="avg"
        )
        preprocess = _mobilenetv3_preprocess
    else:
        raise ValueError(f"Unknown backbone: {backbone_name}")
    return base, preprocess


def build_model(num_classes: int, backbone_name: str = config.BACKBONE) -> tf.keras.Model:
    """Input (0-1 floats, native 240x320 thermal frame) -> backbone
    preprocessing -> pretrained backbone -> dropout -> dense softmax head.

    data_pipeline.py already scales images to [0, 1]; this model re-applies
    the backbone-specific preprocessing internally so the same
    preprocessing is guaranteed at both training and inference time.
    """
    input_shape = (*config.IMAGE_SIZE, config.CHANNELS)
    base, preprocess_fn = _build_backbone(backbone_name, input_shape)
    base.trainable = False  # Phase 1: frozen backbone, train head only.

    inputs = layers.Input(shape=input_shape, name="thermal_image")
    x = layers.Rescaling(scale=255.0)(inputs)  # undo the /255 from data_pipeline
    x = layers.Lambda(preprocess_fn, name="backbone_preprocess")(x)
    x = base(x, training=False)
    x = layers.Dropout(config.DROPOUT_RATE, name="head_dropout")(x)
    outputs = layers.Dense(
        num_classes,
        activation="softmax",
        kernel_regularizer=tf.keras.regularizers.l2(config.WEIGHT_DECAY),
        name="predictions",
    )(x)

    model = models.Model(inputs, outputs, name=f"thermal_bellpepper_{backbone_name}")
    model.backbone = base  # convenience handle used by train.py for unfreezing
    return model


def unfreeze_top_layers(model: tf.keras.Model, n_layers: int = config.FINE_TUNE_UNFREEZE_LAST_N_LAYERS) -> None:
    """Phase 2: unfreeze the last N layers of the backbone for fine-tuning.
    BatchNorm layers are kept frozen to avoid destroying the pretrained
    running statistics on a small dataset (500 images total)."""
    base = model.backbone
    base.trainable = True
    freeze_until = max(0, len(base.layers) - n_layers)
    for layer in base.layers[:freeze_until]:
        layer.trainable = False
    for layer in base.layers[freeze_until:]:
        if isinstance(layer, layers.BatchNormalization):
            layer.trainable = False
