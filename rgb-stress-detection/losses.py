"""
Loss functions for the imbalanced RGB stress-classification task.

Categorical focal loss down-weights easy/majority-class examples (Healthy)
and focuses gradient on hard/minority examples (Aphid, Thrips), combined
with the per-class class_weights already applied in train.py (see analysis
doc Section 4.6 - "do MULTIPLE of these together, not just one").
"""

from __future__ import annotations

import tensorflow as tf


def categorical_focal_loss(gamma: float = 2.0, label_smoothing: float = 0.0):
    """Returns a loss function compatible with model.compile(loss=...).

    y_true, y_pred are one-hot / softmax vectors of shape (batch, n_classes).
    """

    def loss_fn(y_true: tf.Tensor, y_pred: tf.Tensor) -> tf.Tensor:
        if label_smoothing > 0.0:
            n_classes = tf.cast(tf.shape(y_true)[-1], y_true.dtype)
            y_true = y_true * (1.0 - label_smoothing) + label_smoothing / n_classes

        y_pred = tf.clip_by_value(y_pred, 1e-7, 1.0 - 1e-7)
        cross_entropy = -y_true * tf.math.log(y_pred)
        modulating_factor = tf.pow(1.0 - y_pred, gamma)
        loss = modulating_factor * cross_entropy
        return tf.reduce_sum(loss, axis=-1)

    return loss_fn
