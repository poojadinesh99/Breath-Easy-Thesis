#!/usr/bin/env python3
import os
import sys
import json
import argparse
import warnings
from pathlib import Path
from typing import Tuple, List, Dict, Optional

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline
import joblib

# Audio/feature deps
import librosa
import soundfile as sf

# OpenSMILE (python wrapper)
try:
    import opensmile
    HAVE_OPENSMILE = True
except Exception:
    HAVE_OPENSMILE = False
    warnings.warn("opensmile not found. Falling back to librosa-based features.")

# ----------------------------
# Constants / Defaults
# ----------------------------
N_FEATURES_EXPECTED = 120
MODEL_OUT_PATH = Path("backend/ml/models/model_rf.pkl")
LABEL_MAP_OUT_PATH = Path("backend/ml/models/label_map.json")

# Default dataset locations to auto-detect
DEFAULT_DATASET_HINTS = [
    Path("data"),
    Path("backend/data"),
    Path("dataset"),
    Path("datasets"),
    Path("."),
]

AUDIO_EXTS = {".wav", ".flac", ".mp3", ".ogg", ".m4a", ".aac"}

# Allowed acoustic classes for retraining
ALLOWED_CLASSES = {"normal", "cough", "heavy_breathing", "throat_clearing", "silence"}


# ----------------------------
# Utilities
# ----------------------------
def ensure_output_dirs():
    MODEL_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    LABEL_MAP_OUT_PATH.parent.mkdir(parents=True, exist_ok=True)


def find_dataset_path(user_path: Optional[str]) -> Path:
    if user_path:
        p = Path(user_path).expanduser().resolve()
        if not p.exists():
            raise FileNotFoundError(f"Dataset path not found: {p}")
        return p

    for base in DEFAULT_DATASET_HINTS:
        for csv_name in ["features.csv", "data.csv", "train.csv"]:
            p = (base / csv_name).resolve()
            if p.exists() and p.suffix.lower() == ".csv":
                return p
        if base.exists() and base.is_dir():
            subdirs = [d for d in base.iterdir() if d.is_dir()]
            if subdirs:
                for d in subdirs:
                    if any((d / f).suffix.lower() in AUDIO_EXTS for f in os.listdir(d) if (d / f).is_file()):
                        return base
    raise FileNotFoundError("Could not auto-detect dataset. Please pass --data PATH.")


def is_csv_dataset(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() == ".csv"


def list_audio_files_by_class(root: Path) -> Dict[str, List[Path]]:
    classes = {}
    for cls_dir in sorted([d for d in root.iterdir() if d.is_dir()]):
        # Only include allowed acoustic classes
        if cls_dir.name not in ALLOWED_CLASSES:
            continue
        audio_files = []
        for f in sorted(cls_dir.rglob("*")):
            if f.is_file() and f.suffix.lower() in AUDIO_EXTS:
                audio_files.append(f)
        if audio_files:
            classes[cls_dir.name] = audio_files
    if not classes:
        raise RuntimeError(f"No allowed class folders with audio found under: {root}. Allowed classes: {ALLOWED_CLASSES}")
    return classes


# ----------------------------
# Feature Extraction
# ----------------------------
def extract_opensmile_features_audio(y: np.ndarray, sr: int) -> np.ndarray:
    if not HAVE_OPENSMILE:
        raise RuntimeError("OpenSMILE not available.")
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmpf:
        sf.write(tmpf.name, y, sr)
        smile = opensmile.Smile(
            feature_set=opensmile.FeatureSet.eGeMAPSv02,
            feature_level=opensmile.FeatureLevel.Functionals,
        )
        feats = smile.process_file(tmpf.name)
        vec = feats.iloc[0].values.astype(np.float32)
    return vec


def extract_librosa_features_audio(y: np.ndarray, sr: int) -> np.ndarray:
    feats = []
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=20)
    feats.append(mfcc.mean(axis=1))
    feats.append(mfcc.std(axis=1))
    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    feats.append(chroma.mean(axis=1))
    feats.append(chroma.std(axis=1))
    contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
    feats.append(contrast.mean(axis=1))
    feats.append(contrast.std(axis=1))
    tonnetz = librosa.feature.tonnetz(y=librosa.effects.harmonic(y), sr=sr)
    feats.append(tonnetz.mean(axis=1))
    feats.append(tonnetz.std(axis=1))
    zcr = librosa.feature.zero_crossing_rate(y)
    feats.append(np.array([zcr.mean(), zcr.std()]))
    sc = librosa.feature.spectral_centroid(y=y, sr=sr)
    sbw = librosa.feature.spectral_bandwidth(y=y, sr=sr)
    sro = librosa.feature.spectral_rolloff(y=y, sr=sr)
    feats.append(np.array([sc.mean(), sc.std(), sbw.mean(), sbw.std(), sro.mean(), sro.std()]))
    rms = librosa.feature.rms(y=y)
    feats.append(np.array([rms.mean(), rms.std()]))
    try:
        tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
    except Exception:
        tempo = 0.0
    feats.append(np.array([tempo, np.abs(librosa.onset.onset_strength(y=y, sr=sr)).mean()]))
    d_mfcc = librosa.feature.delta(mfcc, order=1)
    feats.append(d_mfcc.mean(axis=1))

    # Add statistical features that help distinguish cough vs normal
    feats.append(np.array([
        np.var(rms),
        np.mean(rms),
        np.mean(zcr)
    ]))

    vec = np.concatenate(feats, axis=0).astype(np.float32)
    if vec.shape[0] > N_FEATURES_EXPECTED:
        vec = vec[:N_FEATURES_EXPECTED]
    elif vec.shape[0] < N_FEATURES_EXPECTED:
        vec = np.pad(vec, (0, N_FEATURES_EXPECTED - vec.shape[0]))
    return vec


def extract_features_file(path: Path, target_sr: int = 16000) -> np.ndarray:
    y, sr = librosa.load(path.as_posix(), sr=target_sr, mono=True)
    y = librosa.util.normalize(y)
    if HAVE_OPENSMILE:
        try:
            vec = extract_opensmile_features_audio(y, sr)
        except Exception:
            vec = extract_librosa_features_audio(y, sr)
    else:
        vec = extract_librosa_features_audio(y, sr)
    if vec.shape[0] > N_FEATURES_EXPECTED:
        vec = vec[:N_FEATURES_EXPECTED]
    elif vec.shape[0] < N_FEATURES_EXPECTED:
        vec = np.pad(vec, (0, N_FEATURES_EXPECTED - vec.shape[0]))
    return vec


# ----------------------------
# Dataset Loaders
# ----------------------------
def load_csv_dataset(csv_path: Path) -> Tuple[np.ndarray, np.ndarray]:
    df = pd.read_csv(csv_path, header=None)
    if df.shape[1] == 1:
        raise ValueError("CSV has only one column. It must include both filename and label.")
    elif df.shape[1] == 2:
        # Check if first column looks like filenames (ends with audio extensions)
        first_col = df.iloc[:, 0].astype(str)
        is_filename_col = any(
            any(str(val).lower().endswith(ext) for ext in AUDIO_EXTS)
            for val in first_col.head(5)  # Check first 5 rows
        )
        if is_filename_col:
            # Treat as filename and label columns
            df.columns = ["filename", "label"]
            X_list, y_list = [], []
            data_dir = csv_path.parent

            for i, row in df.iterrows():
                file_path = data_dir / row["filename"]
                if not file_path.exists():
                    warnings.warn(f"File not found: {file_path}")
                    continue
                try:
                    vec = extract_features_file(file_path)
                    X_list.append(vec)
                    y_list.append(row["label"])
                except Exception as e:
                    warnings.warn(f"Failed to extract features from {file_path}: {e}")

            if not X_list:
                raise RuntimeError("No audio features could be extracted. Check your CSV and file paths.")

            X = np.vstack(X_list)
            y = np.array(y_list, dtype=str)
        else:
            # Treat as features and label (last column is label, first is features)
            print(f"[INFO] Detected 2 columns, first does not look like filenames. Treating as pre-extracted features + label.")
            X = df.iloc[:, :-1].values.astype(np.float32)
            y = df.iloc[:, -1].values.astype(str)
    else:
        # Assume features + label (last column is label, rest are features)
        print(f"[INFO] Detected {df.shape[1]} columns. Treating as pre-extracted features + label.")
        X = df.iloc[:, :-1].values.astype(np.float32)
        y = df.iloc[:, -1].values.astype(str)
    return X, y


def load_folder_dataset(root: Path) -> Tuple[np.ndarray, np.ndarray]:
    by_class = list_audio_files_by_class(root)
    X_list, y_list = [], []

    # Balance classes by taking at most 25 samples per class (to match normal class size)
    max_samples_per_class = 25

    for label, files in by_class.items():
        if label == "silence":
            continue  # Skip silence as it has no samples
        sampled_files = files[:max_samples_per_class]  # Undersample majority classes
        print(f"[INFO] Using {len(sampled_files)} samples for class '{label}' (from {len(files)} available)")

        for f in sampled_files:
            try:
                vec = extract_features_file(f)
                X_list.append(vec)
                y_list.append(label)
            except Exception as e:
                warnings.warn(f"Failed to extract features from {f}: {e}")

    if not X_list:
        raise RuntimeError("No features extracted from folder dataset.")
    return np.vstack(X_list), np.array(y_list, dtype=str)


# ----------------------------
# Training Function
# ----------------------------
def train_rf_balanced(X: np.ndarray, y: np.ndarray, random_state: int = 42):
    le = LabelEncoder()
    y_enc = le.fit_transform(y)

    # Compute class weights automatically
    classes = np.unique(y_enc)
    weights = compute_class_weight(class_weight="balanced", classes=classes, y=y_enc)
    weight_map = dict(zip(classes, weights))
    print("\n[INFO] Computed class weights:", weight_map)

    # --- Safe stratified split ---
    try:
        X_train, X_test, y_train, y_test = train_test_split(
            X, y_enc, test_size=0.2, random_state=random_state, stratify=y_enc
        )
    except ValueError as e:
        print(f"[WARN] Stratified split failed: {e}")
        unique, counts = np.unique(y_enc, return_counts=True)
        small_classes = [u for u, c in zip(unique, counts) if c < 2]
        if small_classes:
            print(f"[INFO] Removing classes with <2 samples: {small_classes}")
            mask = ~np.isin(y_enc, small_classes)
            X, y_enc = X[mask], y_enc[mask]
        X_train, X_test, y_train, y_test = train_test_split(
            X, y_enc, test_size=0.2, random_state=random_state, stratify=None
        )

    # Use SMOTE for oversampling minority classes
    smote = SMOTE(random_state=random_state, k_neighbors=1)  # k_neighbors=1 to handle small classes
    X_train_smote, y_train_smote = smote.fit_resample(X_train, y_train)

    print(f"[INFO] Original training samples: {X_train.shape[0]}")
    print(f"[INFO] SMOTE training samples: {X_train_smote.shape[0]}")

    clf = RandomForestClassifier(
        n_estimators=100,
        max_depth=None,
        random_state=random_state,
        n_jobs=-1,
        class_weight=None  # Remove class weights to avoid bias
    )
    clf.fit(X_train_smote, y_train_smote)

    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f"[RESULT] Validation accuracy: {acc:.4f}")
    # Get the classes present in y_test
    unique_classes = np.unique(y_test)
    class_names = [le.classes_[i] for i in unique_classes]
    print("[RESULT] Detailed metrics:\n", classification_report(y_test, y_pred, target_names=class_names))

    return clf, acc, le


# ----------------------------
# Save Artifacts
# ----------------------------
def save_artifacts(model: RandomForestClassifier, le: LabelEncoder):
    ensure_output_dirs()
    joblib.dump(model, MODEL_OUT_PATH)
    with open(LABEL_MAP_OUT_PATH, "w") as f:
        json.dump({str(i): lab for i, lab in enumerate(le.classes_)}, f, indent=2)
    print(f"[OK] Saved model to: {MODEL_OUT_PATH}")
    print(f"[OK] Saved label map to: {LABEL_MAP_OUT_PATH}")


# ----------------------------
# CLI
# ----------------------------
def parse_args():
    ap = argparse.ArgumentParser(description="Train RandomForest model for Breath Easy.")
    ap.add_argument("--data", type=str, default=None, help="Path to dataset (CSV or folder)")
    ap.add_argument("--csv", action="store_true", help="Force CSV mode.")
    ap.add_argument("--folder", action="store_true", help="Force folder mode.")
    return ap.parse_args()


def main():
    args = parse_args()
    data_path = find_dataset_path(args.data)
    print(f"[INFO] Using dataset at: {data_path}")

    if args.csv and args.folder:
        raise ValueError("Choose only one of --csv or --folder.")
    mode_csv = is_csv_dataset(data_path) if not (args.csv or args.folder) else args.csv

    X, y = load_csv_dataset(data_path) if mode_csv else load_folder_dataset(data_path)

    if X.shape[1] != N_FEATURES_EXPECTED:
        print(f"[WARN] Adjusting features from {X.shape[1]} to {N_FEATURES_EXPECTED}.")
        X = X[:, :N_FEATURES_EXPECTED] if X.shape[1] > N_FEATURES_EXPECTED else np.pad(X, ((0, 0), (0, N_FEATURES_EXPECTED - X.shape[1])))

    print(f"[INFO] Samples: {X.shape[0]}, Features: {X.shape[1]}")
    print(f"[INFO] Classes: {len(np.unique(y))} -> {sorted(np.unique(y).tolist())}")

    model, acc, le = train_rf_balanced(X, y)
    save_artifacts(model, le)
    print("[DONE] Training complete.")


if __name__ == "__main__":
    main()
