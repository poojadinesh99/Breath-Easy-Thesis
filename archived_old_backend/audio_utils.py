# utils/audio_utils.py
import os
import json
import logging
from typing import List, Dict, Tuple, Optional

import librosa
import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ---------------------------
# Feature utilities
# ---------------------------
def aggregate_features(features: np.ndarray, mode: str = "meanstd") -> np.ndarray:
    """
    Aggregate 2D features along the time axis.

    Args:
        features: 2D array (n_features, n_frames)
        mode: "meanstd" -> concatenate mean & std (1D vector); "raw" -> keep 2D

    Returns:
        np.ndarray
    """
    if mode == "raw":
        return features
    if mode == "meanstd":
        mean_features = np.mean(features, axis=1)
        std_features = np.std(features, axis=1)
        return np.concatenate([mean_features, std_features])
    raise ValueError(f"Unknown aggregation mode: {mode}")


def load_audio(file_path: str, sr: int = 16000, duration: float = 5.0) -> Optional[np.ndarray]:
    """
    Load audio, resample to sr, and trim/pad to exactly 'duration' seconds.
    """
    try:
        audio, orig_sr = librosa.load(file_path, sr=None, mono=True)
        if orig_sr != sr:
            audio = librosa.resample(y=audio, orig_sr=orig_sr, target_sr=sr)
        max_len = int(sr * duration)
        if len(audio) > max_len:
            audio = audio[:max_len]
        else:
            audio = np.pad(audio, (0, max_len - len(audio)), mode="constant")
        return audio
    except Exception as e:
        logger.error(f"Error loading audio file {file_path}: {e}")
        return None


def extract_mfcc_features(
    audio: np.ndarray,
    sr: int = 16000,
    n_mfcc: int = 20,      # a bit higher
    n_fft: int = 2048,
    hop_length: int = 512,
    normalize: bool = True,
) -> Optional[np.ndarray]:
    try:
        mfcc = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=n_mfcc, n_fft=n_fft, hop_length=hop_length)
        delta = librosa.feature.delta(mfcc, order=1)
        delta2 = librosa.feature.delta(mfcc, order=2)
        feats = np.vstack([mfcc, delta, delta2])   # shape: (3*n_mfcc, T)
        if normalize:
            feats = (feats - np.mean(feats, axis=1, keepdims=True)) / (np.std(feats, axis=1, keepdims=True) + 1e-6)
        return feats
    except Exception as e:
        logger.error(f"Error extracting MFCC+Δ features: {e}")
        return None


def extract_mel_spectrogram(
    audio: np.ndarray,
    sr: int = 16000,
    n_mels: int = 40,
    n_fft: int = 2048,
    hop_length: int = 512,
    normalize: bool = True,
) -> Optional[np.ndarray]:
    """
    Extract log-mel spectrogram and (optionally) per-bin z-normalize along time.
    """
    try:
        mel_spec = librosa.feature.melspectrogram(y=audio, sr=sr, n_mels=n_mels, n_fft=n_fft, hop_length=hop_length)
        log_mel_spec = librosa.power_to_db(mel_spec, ref=np.max)
        if normalize:
            log_mel_spec = (log_mel_spec - np.mean(log_mel_spec, axis=1, keepdims=True)) / (
                np.std(log_mel_spec, axis=1, keepdims=True) + 1e-6
            )
        return log_mel_spec
    except Exception as e:
        logger.error(f"Error extracting Mel spectrogram features: {e}")
        return None


# ---------------------------
# Label map utilities
# ---------------------------
def build_label_map(csv_paths: List[str], diagnosis_columns: List[str]) -> Dict[str, int]:
    """
    Build label->id from one or more CSVs and diagnosis columns.
    """
    labels = set()
    for csv_path in csv_paths:
        try:
            df = pd.read_csv(csv_path)
            for col in diagnosis_columns:
                if col in df.columns:
                    labels.update(str(v).strip().lower() for v in df[col].dropna().unique() if str(v).strip())
                else:
                    logger.warning(f"Column '{col}' not found in {csv_path}")
        except Exception as e:
            logger.error(f"Error reading CSV file {csv_path}: {e}")
    label_list = sorted(labels)
    label_map = {label: idx for idx, label in enumerate(label_list)}
    logger.info(f"Built label map with {len(label_map)} labels: {label_list}")
    return label_map


def save_label_map(label_map: Dict[str, int], json_path: str) -> None:
    try:
        with open(json_path, "w") as f:
            json.dump(label_map, f, indent=4)
        logger.info(f"Saved label map to {json_path}")
    except Exception as e:
        logger.error(f"Error saving label map to {json_path}: {e}")


def load_label_map(json_path: str) -> Optional[Dict[str, int]]:
    try:
        with open(json_path, "r") as f:
            label_map = json.load(f)
        logger.info(f"Loaded label map from {json_path}")
        return label_map
    except Exception as e:
        logger.error(f"Error loading label map from {json_path}: {e}")
        return None


# ---------------------------
# Core processing
# ---------------------------
def process_audio_and_label(
    audio_path: str,
    label: str,
    label_map: Dict[str, int],
    feature_type: str = "mfcc",
    duration: float = 5.0,
    sr: int = 16000,
    n_fft: int = 2048,
    hop_length: int = 512,
    normalize: bool = True,
    mode: str = "meanstd",
):
    """
    Load audio, extract features, aggregate, and map label->int.
    Returns (features, label_id) or None on failure.
    """
    audio = load_audio(audio_path, sr=sr, duration=duration)
    if audio is None:
        logger.error(f"Failed to load audio for {audio_path}")
        return None

    if feature_type == "mfcc":
        features = extract_mfcc_features(audio, sr=sr, n_fft=n_fft, hop_length=hop_length, normalize=normalize)
    elif feature_type == "mel":
        features = extract_mel_spectrogram(audio, sr=sr, n_fft=n_fft, hop_length=hop_length, normalize=normalize)
    else:
        logger.error(f"Unknown feature_type '{feature_type}'")
        return None

    if features is None:
        logger.error(f"Feature extraction failed for {audio_path}")
        return None

    features = aggregate_features(features, mode=mode)
    label_id = label_map.get(label.strip().lower())
    if label_id is None:
        logger.warning(f"Label '{label}' not in label_map; skipping {audio_path}")
        return None
    return features, label_id


# ---------------------------
# Kaggle Respiratory loader (annotation-driven)
# ---------------------------
def _read_kaggle_annotation(txt_path: str) -> Dict[str, bool]:
    """
    Read a Kaggle Respiratory .txt annotation with flexible column counts:
      - 4 columns: start end crackles wheezes
      - 3 columns: start end crackles (wheezes assumed 0)
      - 2 columns: start end (both assumed 0)
    Returns dict: {"has_crackles": bool, "has_wheezes": bool}
    """
    try:
        df = pd.read_csv(txt_path, sep=r"\s+", header=None, engine="python")
    except Exception as e:
        logger.warning(f"Failed to read annotation {txt_path}: {e}")
        return {"has_crackles": False, "has_wheezes": False}

    ncols = df.shape[1]
    has_crackles = False
    has_wheezes = False

    if ncols >= 4:
        # cols: start, end, crackles, wheezes
        df.columns = ["start", "end", "crackles", "wheezes"]
        has_crackles = bool((df["crackles"] == 1).any())
        has_wheezes = bool((df["wheezes"] == 1).any())
    elif ncols == 3:
        # cols: start, end, crackles
        df.columns = ["start", "end", "crackles"]
        has_crackles = bool((df["crackles"] == 1).any())
        has_wheezes = False
    elif ncols == 2:
        # cols: start, end (no abnormal flags)
        df.columns = ["start", "end"]
        has_crackles = False
        has_wheezes = False
    else:
        logger.warning(f"Unexpected annotation format ({ncols} columns) in {txt_path}")

    return {"has_crackles": has_crackles, "has_wheezes": has_wheezes}


def load_kaggle_features_from_annotations(
    audio_dir: str,
    feature_type: str = "mfcc",
    duration: float = 5.0,
    sr: int = 16000,
    n_fft: int = 2048,
    hop_length: int = 512,
    normalize: bool = True,
    mode: str = "meanstd",
) -> Tuple[np.ndarray, np.ndarray, List[str]]:
    """
    Build dataset from Kaggle Respiratory folder using .txt annotations.
    Label rule:
        if any row has crackles==1 or wheezes==1 -> 'abnormal'
        else -> 'clear'
    Returns:
        X (np.ndarray), y (np.ndarray), classes (['abnormal','clear'])
    """
    classes = ["abnormal", "clear"]
    label_map = {c: i for i, c in enumerate(classes)}
    X, y = [], []

    for fname in os.listdir(audio_dir):
        if not fname.endswith(".txt"):
            continue
        stem = os.path.splitext(fname)[0]
        txt_path = os.path.join(audio_dir, fname)
        wav_path = os.path.join(audio_dir, stem + ".wav")
        if not os.path.exists(wav_path):
            logger.warning(f"Missing wav for annotation: {txt_path}")
            continue

        flags = _read_kaggle_annotation(txt_path)
        label_str = "abnormal" if (flags["has_crackles"] or flags["has_wheezes"]) else "clear"

        result = process_audio_and_label(
            audio_path=wav_path,
            label=label_str,
            label_map=label_map,
            feature_type=feature_type,
            duration=duration,
            sr=sr,
            n_fft=n_fft,
            hop_length=hop_length,
            normalize=normalize,
            mode=mode,
        )
        if result is None:
            continue
        feat, _ = result
        X.append(feat)
        y.append(label_map[label_str])

    X = np.array(X)
    y = np.array(y)
    if len(X) == 0:
        logger.error("No samples were built from Kaggle annotations. Check folder structure and .txt format.")
    else:
        logger.info(f"Kaggle loader: {len(X)} samples | classes={classes}")
    return X, y, classes


# ---------------------------
# Flexible CSV-based loader (works with 'filename' or 'id')
# ---------------------------
def load_all_audio_features_and_labels_csv(
    audio_dir: str,
    csv_path: str,
    label_map_path: str,
    feature_type: str = "mfcc",
    duration: float = 5.0,
    sr: int = 16000,
    n_fft: int = 2048,
    hop_length: int = 512,
    normalize: bool = True,
    mode: str = "meanstd",
    filename_column: Optional[str] = None,
    label_column: str = "label",
    match_strategy: str = "exact",  # "exact" | "stem" | "prefix"
) -> Tuple[np.ndarray, np.ndarray]:
    """
    CSV-driven loader that can map either 'filename' or 'id' to .wav files.

    match_strategy:
      - "exact"  : CSV value includes extension; matches file name exactly.
      - "stem"   : compare stems (strip extension) to CSV values.
      - "prefix" : treat CSV value as prefix of the file stem.

    This function is robust to CSVs that have 'id' instead of 'filename'.
    """
    label_map = load_label_map(label_map_path)
    if label_map is None:
        raise ValueError("Label map could not be loaded.")

    try:
        df = pd.read_csv(csv_path)
    except Exception as e:
        logger.error(f"Error reading CSV {csv_path}: {e}")
        raise

    # Auto-detect columns if not provided
    if filename_column is None:
        if "filename" in df.columns:
            filename_column = "filename"
        elif "id" in df.columns:
            filename_column = "id"
        else:
            raise ValueError(
                f"No filename/id column found in CSV. Columns: {df.columns.tolist()}"
            )

    if label_column not in df.columns:
        raise ValueError(
            f"Label column '{label_column}' not found in CSV. Columns: {df.columns.tolist()}"
        )

    # Build dictionary from CSV
    id_to_label = {
        str(row[filename_column]).strip(): str(row[label_column]).strip().lower()
        for _, row in df.iterrows()
        if str(row[label_column]).strip()
    }

    # Index audio files
    audio_files = [f for f in os.listdir(audio_dir) if f.lower().endswith((".wav", ".mp3"))]
    file_stems = {os.path.splitext(f)[0]: f for f in audio_files}

    X, y = [], []
    misses = 0

    for key, label_str in id_to_label.items():
        file_to_use = None

        if match_strategy == "exact":
            # key is full filename
            if key in audio_files:
                file_to_use = key
        elif match_strategy == "stem":
            # compare stems
            if key in file_stems:
                file_to_use = file_stems[key]
        elif match_strategy == "prefix":
            # CSV id matches start of file stem
            candidates = [fname for stem, fname in file_stems.items() if stem.startswith(key)]
            if candidates:
                file_to_use = candidates[0]
        else:
            raise ValueError("match_strategy must be one of: 'exact','stem','prefix'")

        if file_to_use is None:
            misses += 1
            continue

        if label_str not in label_map:
            logger.warning(f"Label '{label_str}' not in label_map; skipping file {file_to_use}")
            continue

        file_path = os.path.join(audio_dir, file_to_use)
        res = process_audio_and_label(
            audio_path=file_path,
            label=label_str,
            label_map=label_map,
            feature_type=feature_type,
            duration=duration,
            sr=sr,
            n_fft=n_fft,
            hop_length=hop_length,
            normalize=normalize,
            mode=mode,
        )
        if res is None:
            continue
        feat, label_id = res
        X.append(feat)
        y.append(label_id)

    if misses:
        logger.warning(f"{misses} CSV rows did not match any audio file using strategy='{match_strategy}'.")

    return np.array(X), np.array(y)
