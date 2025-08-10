import os
import json
import logging
from typing import List, Dict, Tuple, Optional
import argparse
import librosa
import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def load_audio(file_path: str, sr: int = 16000, duration: float = 5.0) -> Optional[np.ndarray]:
    """
    Load an audio file (wav or mp3), resample to `sr` Hz, and trim/pad to `duration` seconds.

    Args:
        file_path (str): Path to the audio file.
        sr (int): Target sampling rate (default 16000).
        duration (float): Duration in seconds to trim or pad the audio (default 5.0).

    Returns:
        np.ndarray: Audio time series array of shape (sr * duration,)
    """
    try:
        audio, orig_sr = librosa.load(file_path, sr=None, mono=True)
        if orig_sr != sr:
            audio = librosa.resample(audio, orig_sr, sr)
        max_len = int(sr * duration)
        if len(audio) > max_len:
            audio = audio[:max_len]
        else:
            audio = np.pad(audio, (0, max_len - len(audio)), mode='constant')
        return audio
    except Exception as e:
        logger.error(f"Error loading audio file {file_path}: {e}")
        return None

def extract_mfcc_features(audio: np.ndarray, sr: int = 16000, n_mfcc: int = 13) -> Optional[np.ndarray]:
    """
    Extract MFCC features from audio and normalize by mean and std.

    Args:
        audio (np.ndarray): Audio time series.
        sr (int): Sampling rate.
        n_mfcc (int): Number of MFCC coefficients.

    Returns:
        np.ndarray: Normalized MFCC feature array.
    """
    try:
        mfcc = librosa.feature.mfcc(y=audio, sr=sr, n_mfcc=n_mfcc)
        mfcc_norm = (mfcc - np.mean(mfcc, axis=1, keepdims=True)) / (np.std(mfcc, axis=1, keepdims=True) + 1e-6)
        return mfcc_norm
    except Exception as e:
        logger.error(f"Error extracting MFCC features: {e}")
        return None

def extract_mel_spectrogram(audio: np.ndarray, sr: int = 16000, n_mels: int = 40) -> Optional[np.ndarray]:
    """
    Extract Mel spectrogram features from audio and normalize by mean and std.

    Args:
        audio (np.ndarray): Audio time series.
        sr (int): Sampling rate.
        n_mels (int): Number of Mel bands.

    Returns:
        np.ndarray: Normalized Mel spectrogram feature array.
    """
    try:
        mel_spec = librosa.feature.melspectrogram(y=audio, sr=sr, n_mels=n_mels)
        log_mel_spec = librosa.power_to_db(mel_spec, ref=np.max)
        mel_spec_norm = (log_mel_spec - np.mean(log_mel_spec, axis=1, keepdims=True)) / (np.std(log_mel_spec, axis=1, keepdims=True) + 1e-6)
        return mel_spec_norm
    except Exception as e:
        logger.error(f"Error extracting Mel spectrogram features: {e}")
        return None

def build_label_map(csv_paths: List[str], diagnosis_columns: List[str]) -> Dict[str, int]:
    """
    Build a label-to-ID map from diagnosis columns in one or more CSV files.

    Args:
        csv_paths (List[str]): List of CSV file paths.
        diagnosis_columns (List[str]): List of column names containing diagnosis labels.

    Returns:
        Dict[str, int]: Mapping from label string to integer ID.
    """
    labels = set()
    for csv_path in csv_paths:
        try:
            df = pd.read_csv(csv_path)
            for col in diagnosis_columns:
                if col in df.columns:
                    col_labels = df[col].dropna().unique()
                    labels.update(str(label).strip() for label in col_labels if label)
                else:
                    logger.warning(f"Column '{col}' not found in {csv_path}")
        except Exception as e:
            logger.error(f"Error reading CSV file {csv_path}: {e}")
    label_list = sorted(labels)
    label_map = {label: idx for idx, label in enumerate(label_list)}
    logger.info(f"Built label map with {len(label_map)} labels")
    return label_map

def save_label_map(label_map: Dict[str, int], json_path: str) -> None:
    """
    Save label map dictionary to a JSON file.

    Args:
        label_map (Dict[str, int]): Label to ID mapping.
        json_path (str): Path to save JSON file.
    """
    try:
        with open(json_path, 'w') as f:
            json.dump(label_map, f, indent=4)
        logger.info(f"Saved label map to {json_path}")
    except Exception as e:
        logger.error(f"Error saving label map to {json_path}: {e}")

def load_label_map(json_path: str) -> Optional[Dict[str, int]]:
    """
    Load label map dictionary from a JSON file.

    Args:
        json_path (str): Path to JSON file.

    Returns:
        Dict[str, int]: Label to ID mapping.
    """
    try:
        with open(json_path, 'r') as f:
            label_map = json.load(f)
        logger.info(f"Loaded label map from {json_path}")
        return label_map
    except Exception as e:
        logger.error(f"Error loading label map from {json_path}: {e}")
        return None

def process_audio_and_label(audio_path: str, label: str, label_map: Dict[str, int], feature_type: str = 'mfcc', duration: float = 5.0):

    """
    Full pipeline to load audio, extract features, and map label to ID.

    Args:
        audio_path (str): Path to audio file.
        label (str): String label.
        label_map (Dict[str, int]): Label to ID mapping.
        feature_type (str): 'mfcc' or 'mel' for feature extraction.

    Returns:
        Tuple[np.ndarray, int]: Feature array and label ID.
    """
    audio = load_audio(audio_path, duration=duration)

    if audio is None:
        logger.error(f"Failed to load audio for {audio_path}")
        return None
    if feature_type == 'mfcc':
        features = extract_mfcc_features(audio)
    elif feature_type == 'mel':
        features = extract_mel_spectrogram(audio)
    else:
        logger.error(f"Unknown feature_type '{feature_type}'")
        return None
    if features is None:
        logger.error(f"Feature extraction failed for {audio_path}")
        return None
    label_id = label_map.get(label.strip().lower())

    if label_id is None:
        logger.warning(f"Label '{label}' not found in label map")
        return None
    return features, label_id

def load_all_audio_features_and_labels(audio_dir: str, label_map_path: str, feature_type: str = 'mfcc', duration: float = 5.0) -> Tuple[np.ndarray, np.ndarray]:
    """
    Load all audio files from a directory, extract features, and collect labels.

    Args:
        audio_dir (str): Directory containing audio files.
        label_map_path (str): Path to JSON label map.
        feature_type (str): 'mfcc' or 'mel'.
        duration (float): Trim/pad length in seconds.

    Returns:
        Tuple of (features array, labels array)
    """
    label_map = load_label_map(label_map_path)
    if label_map is None:
        raise ValueError("Label map could not be loaded.")

    X = []
    y = []

    for filename in os.listdir(audio_dir):
        if filename.endswith(".wav") or filename.endswith(".mp3"):
            parts = filename.split("_")
            label = parts[0].lower()  # Adjust this depending on your filename format
            file_path = os.path.join(audio_dir, filename)
            result = process_audio_and_label(file_path, label, label_map, feature_type=feature_type, duration=duration)
            if result:
                features, label_id = result
                X.append(features.flatten())  # Flatten to 1D
                y.append(label_id)

    return np.array(X), np.array(y)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Audio utils for respiratory disease classification")
    parser.add_argument('--csvs', nargs='+', required=True, help='Paths to CSV files with diagnosis columns')
    parser.add_argument('--diagnosis_cols', nargs='+', required=True, help='Diagnosis column names in CSVs')
    parser.add_argument('--audio', required=True, help='Path to audio file to process')
    parser.add_argument('--label', required=True, help='Label string for the audio file')
    parser.add_argument('--feature_type', choices=['mfcc', 'mel'], default='mfcc', help='Feature extraction type')
    parser.add_argument('--label_map_json', default='label_map.json', help='Path to save/load label map JSON')
    parser.add_argument('--duration', type=float, default=5.0, help='Target duration (in seconds) for audio trimming/padding')
    args = parser.parse_args()

    label_map = build_label_map(args.csvs, args.diagnosis_cols)
    save_label_map(label_map, args.label_map_json)

    loaded_label_map = load_label_map(args.label_map_json)
    if loaded_label_map is None:
        logger.error("Failed to load label map, exiting")
        exit(1)

    result = process_audio_and_label(args.audio, args.label, loaded_label_map, args.feature_type, duration=args.duration)
 
    if result is not None:
        features, label_id = result
        logger.info(f"Processed audio file '{args.audio}' with label '{args.label}' (ID: {label_id})")
        logger.info(f"Feature shape: {features.shape}")
        EXPECTED_SHAPE = (13, 157) if args.feature_type == 'mfcc' else (40, 157)  # Adjust 157 based on test file duration
        if features.shape != EXPECTED_SHAPE:
           logger.warning(f"⚠️ Unexpected feature shape: {features.shape} (expected {EXPECTED_SHAPE})")

        # Save as .npy
        np.save(f"{os.path.splitext(args.audio)[0]}_features.npy", features)
        np.save(f"{os.path.splitext(args.audio)[0]}_label.npy", np.array([label_id]))
        
        # Optional: Save as .pkl (if you prefer pickle)
        # import pickle
        # with open(f"{os.path.splitext(args.audio)[0]}_data.pkl", "wb") as f:
        #     pickle.dump((features, label_id), f)

        logger.info("Saved features and label to disk.")
    else:
        logger.error("Processing failed")
