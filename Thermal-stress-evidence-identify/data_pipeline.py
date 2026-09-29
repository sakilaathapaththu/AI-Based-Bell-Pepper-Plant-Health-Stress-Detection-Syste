"""
Data pipeline: discover classes, index thermal images, group near-duplicates,
build a leakage-safe stratified split, and construct tf.data.Dataset objects
for the CNN (Track A).

This file only DEFINES functions. Nothing runs on import. To build and
inspect the split without training, run:

    python data_pipeline.py

which will print class counts and split sizes and write
splits/manifest.csv.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

import imagehash
import numpy as np
import pandas as pd
import tensorflow as tf
from PIL import Image

import config


# ---------------------------------------------------------------------------
# Step 1: Discover classes + index every image file
# ---------------------------------------------------------------------------

def discover_classes(data_dir: Path = config.DATA_DIR) -> list[str]:
    if not data_dir.exists():
        raise FileNotFoundError(f"Dataset directory not found: {data_dir}")
    classes = sorted(p.name for p in data_dir.iterdir() if p.is_dir())
    non_empty = [c for c in classes if any((data_dir / c).glob("*.png"))]
    empty = sorted(set(classes) - set(non_empty))
    if empty:
        print(f"[data_pipeline] Skipping classes with 0 images: {empty}")
    return non_empty


def index_images(data_dir: Path = config.DATA_DIR) -> pd.DataFrame:
    classes = discover_classes(data_dir)
    rows = []
    for class_name in classes:
        for path in sorted((data_dir / class_name).glob("*.png")):
            rows.append({"filepath": str(path), "class": class_name})
    df = pd.DataFrame(rows)
    if df.empty:
        raise RuntimeError(f"No .png images found under {data_dir}")
    return df


# ---------------------------------------------------------------------------
# Step 2: Near-duplicate / same-plant grouping via perceptual hash
#
# No plant/session IDs are provided (analysis doc Section 1/5). Perceptual
# hashing is a practical stand-in: near-identical frames get the same group
# ID and are forced into the same split, preventing leakage.
# ---------------------------------------------------------------------------

def compute_group_ids(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    hashes: list[imagehash.ImageHash | None] = []
    for path in df["filepath"]:
        try:
            with Image.open(path) as im:
                hashes.append(imagehash.phash(im.convert("RGB"), hash_size=config.PHASH_SIZE))
        except Exception as exc:  # pragma: no cover - defensive, corrupt file
            print(f"[data_pipeline] WARNING: could not hash {path}: {exc}")
            hashes.append(None)

    group_id = np.full(len(df), -1, dtype=np.int64)
    next_group = 0
    valid_idx = [i for i, h in enumerate(hashes) if h is not None]

    for i in valid_idx:
        if group_id[i] != -1:
            continue
        group_id[i] = next_group
        for j in valid_idx:
            if group_id[j] != -1:
                continue
            if hashes[i] - hashes[j] <= config.NEAR_DUPLICATE_MAX_DISTANCE:
                group_id[j] = next_group
        next_group += 1

    for i, gid in enumerate(group_id):
        if gid == -1:
            group_id[i] = next_group
            next_group += 1

    df["group_id"] = [f"{row['class']}__g{gid}" for row, gid in zip(df.to_dict("records"), group_id)]
    return df


# ---------------------------------------------------------------------------
# Step 3: Leakage-safe, class-stratified, group-aware split
# ---------------------------------------------------------------------------

def _stable_group_hash(group_id: str) -> float:
    digest = hashlib.sha256(group_id.encode("utf-8")).hexdigest()
    return int(digest[:8], 16) / 0xFFFFFFFF


def build_split(df: pd.DataFrame) -> pd.DataFrame:
    assert abs(config.TRAIN_RATIO + config.VAL_RATIO + config.TEST_RATIO - 1.0) < 1e-6

    df = df.copy()
    df["split"] = ""

    for class_name, class_df in df.groupby("class"):
        groups = class_df["group_id"].unique().tolist()
        group_sizes = class_df.groupby("group_id").size().to_dict()
        groups_sorted = sorted(groups, key=_stable_group_hash)

        total = sum(group_sizes.values())
        train_target = total * config.TRAIN_RATIO
        val_target = total * config.VAL_RATIO

        running = 0
        assignment: dict[str, str] = {}
        for g in groups_sorted:
            if running < train_target:
                assignment[g] = "train"
            elif running < train_target + val_target:
                assignment[g] = "validation"
            else:
                assignment[g] = "test"
            running += group_sizes[g]

        for g, split_name in assignment.items():
            df.loc[df["group_id"] == g, "split"] = split_name

    return df


def build_manifest(data_dir: Path = config.DATA_DIR, save: bool = True) -> pd.DataFrame:
    df = index_images(data_dir)
    df = compute_group_ids(df)
    df = build_split(df)
    if save:
        config.SPLITS_DIR.mkdir(parents=True, exist_ok=True)
        out_path = config.SPLITS_DIR / "manifest.csv"
        df.to_csv(out_path, index=False)
        print(f"[data_pipeline] Wrote manifest with {len(df)} rows to {out_path}")
    return df


# ---------------------------------------------------------------------------
# Step 4: Class weights (mild safety net - classes are already balanced)
# ---------------------------------------------------------------------------

def compute_class_weights(train_df: pd.DataFrame, class_names: list[str]) -> dict[int, float]:
    counts = train_df["class"].value_counts()
    total = counts.sum()
    n_classes = len(class_names)
    weights = {}
    for idx, name in enumerate(class_names):
        count = counts.get(name, 1)
        weights[idx] = total / (n_classes * count)
    return weights


# ---------------------------------------------------------------------------
# Step 5: tf.data pipelines
# ---------------------------------------------------------------------------

def decode_and_resize(image_bytes: tf.Tensor) -> tf.Tensor:
    """Shared decode step used by BOTH training (via load_and_preprocess,
    reading file bytes off disk) AND the inference API (app.py, reading
    bytes from an uploaded/replayed thermal frame) - guarantees identical
    preprocessing at train and serve time."""
    image = tf.image.decode_png(image_bytes, channels=config.CHANNELS)
    image = tf.image.resize(image, config.IMAGE_SIZE, method="bilinear")
    return tf.cast(image, tf.float32)


def preprocess_image_bytes(image_bytes: bytes) -> tf.Tensor:
    """Inference-time preprocessing (no augmentation) for a single raw PNG
    byte string. Returns a (H, W, 3) float32 tensor scaled to [0, 1]."""
    image = decode_and_resize(image_bytes)
    return image / 255.0


def load_and_preprocess(path: tf.Tensor, label: tf.Tensor, training: bool) -> tuple[tf.Tensor, tf.Tensor]:
    file_bytes = tf.io.read_file(path)
    image = decode_and_resize(file_bytes)

    if training:
        image = tf.image.random_flip_left_right(image)
        image = tf.image.random_flip_up_down(image)
        image = tf.image.rot90(image, k=tf.random.uniform([], 0, 4, dtype=tf.int32))
        # Small brightness/contrast jitter only. Large color/hue jitter is
        # deliberately avoided because, for pseudo-color thermal images,
        # the COLOR ITSELF encodes the (proxy) temperature signal that
        # distinguishes stress classes - heavy hue distortion would
        # actively destroy the diagnostic signal, more so than for RGB
        # leaf photos (see analysis doc Section 2/3).
        image = tf.image.random_brightness(image, max_delta=0.08)
        image = tf.image.random_contrast(image, lower=0.95, upper=1.05)
        image = tf.clip_by_value(image, 0.0, 255.0)

    image = image / 255.0
    return image, label


def make_dataset(
    df: pd.DataFrame,
    class_names: list[str],
    training: bool,
    batch_size: int = config.BATCH_SIZE,
) -> tf.data.Dataset:
    class_to_index = {name: i for i, name in enumerate(class_names)}
    paths = df["filepath"].tolist()
    labels = [class_to_index[c] for c in df["class"].tolist()]

    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if training:
        ds = ds.shuffle(buffer_size=min(len(df), 4096), seed=config.RANDOM_SEED, reshuffle_each_iteration=True)

    ds = ds.map(
        lambda p, l: load_and_preprocess(p, l, training=training),
        num_parallel_calls=tf.data.AUTOTUNE,
    )
    ds = ds.map(
        lambda img, lbl: (img, tf.one_hot(lbl, depth=len(class_names))),
        num_parallel_calls=tf.data.AUTOTUNE,
    )
    ds = ds.batch(batch_size)
    ds = ds.prefetch(tf.data.AUTOTUNE)
    return ds


def load_split_datasets(manifest: pd.DataFrame | None = None) -> dict:
    if manifest is None:
        manifest = build_manifest(save=False)

    class_names = sorted(manifest["class"].unique().tolist())
    train_df = manifest[manifest["split"] == "train"]
    val_df = manifest[manifest["split"] == "validation"]
    test_df = manifest[manifest["split"] == "test"]

    return {
        "class_names": class_names,
        "train_df": train_df,
        "val_df": val_df,
        "test_df": test_df,
        "train_ds": make_dataset(train_df, class_names, training=True),
        "val_ds": make_dataset(val_df, class_names, training=False),
        "test_ds": make_dataset(test_df, class_names, training=False),
        "class_weights": compute_class_weights(train_df, class_names),
    }


if __name__ == "__main__":
    # Deliberately not invoked automatically - inspect the split with:
    #   python data_pipeline.py
    manifest = build_manifest(save=True)
    print(manifest.groupby(["class", "split"]).size())
