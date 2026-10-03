"""
Model definition: transfer-learning backbone + classification head, with
helpers to freeze/unfreeze for the two-phase fine-tuning schedule described
in the analysis doc (Section 4.8).

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
# named, registered function fixes this: the registry entry lets
# load_model() find it again, as long as this module has been imported
# (which registers it) before the load happens.
#
# Registered via the standalone `keras` package (Keras 3), not `tf.keras`:
# this TensorFlow/Keras combination does not expose `tf.keras.saving`.
@keras.saving.register_keras_serializable(package="rgb_stress_detection", name="efficientnet_preprocess")
def _efficientnet_preprocess(x):
    return tf.keras.applications.efficientnet.preprocess_input(x)


@keras.saving.register_keras_serializable(package="rgb_stress_detection", name="mobilenetv3_preprocess")
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
    """Builds an end-to-end model: Input (0-1 floats) -> backbone
    preprocessing -> pretrained backbone -> dropout -> dense softmax head.

    The pipeline in data_pipeline.py already scales images to [0, 1]; this
    model re-applies the backbone-specific preprocessing internally so the
    same preprocessing is guaranteed at both training and inference time.
    """
    input_shape = (*config.IMAGE_SIZE, config.CHANNELS)
    base, preprocess_fn = _build_backbone(backbone_name, input_shape)
    base.trainable = False  # Phase 1: frozen backbone, train head only.

    inputs = layers.Input(shape=input_shape, name="image")
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

    model = models.Model(inputs, outputs, name=f"bellpepper_{backbone_name}")
    model.backbone = base  # convenience handle used by train.py for unfreezing
    return model


def unfreeze_top_layers(model: tf.keras.Model, n_layers: int = config.FINE_TUNE_UNFREEZE_LAST_N_LAYERS) -> None:
    """Phase 2: unfreeze the last N layers of the backbone for fine-tuning.
    BatchNorm layers are kept frozen (standard practice) to avoid destroying
    the pretrained running statistics on a small dataset."""
    base = model.backbone
    base.trainable = True
    freeze_until = max(0, len(base.layers) - n_layers)
    for layer in base.layers[:freeze_until]:
        layer.trainable = False
    for layer in base.layers[freeze_until:]:
        if isinstance(layer, layers.BatchNormalization):
            layer.trainable = False


def build_binary_stage_model(backbone_name: str = config.BACKBONE) -> tf.keras.Model:
    """Stage 1 of the cascade (see analysis doc Section 4.1):
    Healthy vs Stressed binary classifier. Same architecture as the flat
    model but with a single sigmoid output."""
    input_shape = (*config.IMAGE_SIZE, config.CHANNELS)
    base, preprocess_fn = _build_backbone(backbone_name, input_shape)
    base.trainable = False

    inputs = layers.Input(shape=input_shape, name="image")
    x = layers.Rescaling(scale=255.0)(inputs)
    x = layers.Lambda(preprocess_fn, name="backbone_preprocess")(x)
    x = base(x, training=False)
    x = layers.Dropout(config.DROPOUT_RATE, name="head_dropout")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="stressed_probability")(x)

    model = models.Model(inputs, outputs, name=f"bellpepper_stage1_{backbone_name}")
    model.backbone = base
    return model
