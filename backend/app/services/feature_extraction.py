"""
Feature extraction module for audio analysis.
Uses OpenSMILE for breath analysis and Whisper for speech analysis.
Enhanced for reliable cough and throat-clearing detection.
"""
import os
import logging
import numpy as np
from typing import Dict, Any, Union
from pathlib import Path
import librosa

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------
# 📦 INITIALIZATION
# ---------------------------------------------------------------------
smile = None
whisper = None

try:
    import opensmile
    smile = opensmile.Smile(
        feature_set=opensmile.FeatureSet.eGeMAPSv02,
        feature_level=opensmile.FeatureLevel.Functionals,
    )
    logger.info("✓ OpenSMILE initialized with eGeMAPSv02 feature set")
except Exception as e:
    logger.warning(f"Failed to load OpenSMILE: {e}")

try:
    from transformers import pipeline
    import warnings
    warnings.filterwarnings("ignore", category=FutureWarning, module="transformers")
    try:
        import torch
        has_torch = True
    except ImportError:
        has_torch = False

    device_map = "auto" if (has_torch and hasattr(torch, "cuda") and torch.cuda.is_available()) else "cpu"
    whisper = pipeline(
        "automatic-speech-recognition",
        model="openai/whisper-tiny",
        chunk_length_s=30,
        device=device_map
    )
    logger.info("✓ Whisper tiny model initialized successfully")

except Exception as e:
    logger.warning(f"Whisper not available: {e}")
    whisper = None


# ---------------------------------------------------------------------
# 🎧 FEATURE EXTRACTION
# ---------------------------------------------------------------------
def extract_features(source: Union[str, Path, np.ndarray], task_type: str = "breath", sr: int = 16000) -> Dict[str, Any]:
    """
    Extracts robust audio features for respiratory or speech classification.
    Returns a dictionary containing engineered features and 120-dimensional model vector.
    """
    features = {}
    try:
        # --------------------------------------------------------------
        # Load and normalize waveform
        # --------------------------------------------------------------
        if isinstance(source, (str, Path)):
            y, sr = librosa.load(str(source), sr=16000)
        elif isinstance(source, np.ndarray):
            y = source.astype(np.float32)
        else:
            raise ValueError(f"Unsupported audio source type: {type(source)}")

        logger.info(f"extract_features received input (sr={sr})")

        rms = np.mean(librosa.feature.rms(y=y))
        if rms > 0.1:
            y = y / (1 + rms * 5)
            logger.info(f"🌬️ High RMS detected ({rms:.3f}) → normalized")

        # --------------------------------------------------------------
        # OpenSMILE features
        # --------------------------------------------------------------
        import soundfile as sf, tempfile
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
            sf.write(tmp.name, y, sr)
            smile_features = smile.process_file(tmp.name)
        opensmile_features = smile_features.values.flatten()
        logger.info(f"OpenSMILE features shape: {opensmile_features.shape}")

        # --------------------------------------------------------------
        # Basic spectral & energy features
        # --------------------------------------------------------------
        features["duration"] = len(y) / sr
        features["rms_energy"] = np.sqrt(np.mean(y ** 2))
        features["zero_crossing_rate"] = np.mean(librosa.feature.zero_crossing_rate(y))
        mel_spec = librosa.feature.melspectrogram(y=y, sr=sr)
        features["spectral_rolloff"] = np.mean(librosa.feature.spectral_rolloff(S=mel_spec))
        features["spectral_centroid"] = np.mean(librosa.feature.spectral_centroid(S=mel_spec))

        # --------------------------------------------------------------
        # Cough/Throat detection engineered features
        # --------------------------------------------------------------
        y_norm = y / (np.max(np.abs(y)) + 1e-8)
        energy_env = librosa.feature.rms(y=y, frame_length=512, hop_length=256)[0]
        energy_thr = np.mean(energy_env) + 2 * np.std(energy_env)
        cough_events = energy_env > energy_thr
        cough_ratio = np.sum(cough_events) / len(cough_events)

        freqs = librosa.fft_frequencies(sr=sr)
        stft = np.abs(librosa.stft(y))
        total_e = np.mean(stft) + 1e-8
        low = np.mean(stft[freqs <= 500]) / total_e
        mid = np.mean(stft[(freqs > 500) & (freqs <= 2000)]) / total_e
        high = np.mean(stft[freqs > 2000]) / total_e

        cough_freq_ratio = mid / (low + 1e-8)
        harsh_ratio = high / (low + 1e-8)
        onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units="frames")
        onset_rate = len(onset_frames) / (len(y) / sr)
        energy_var = np.std(energy_env) / (np.mean(energy_env) + 1e-8)
        signal_strength = np.mean(np.abs(y))

        features.update({
            "cough_event_ratio": cough_ratio,
            "cough_frequency_ratio": cough_freq_ratio,
            "harsh_sound_ratio": harsh_ratio,
            "onset_rate": onset_rate,
            "energy_variation": energy_var,
            "signal_strength": signal_strength
        })

        logger.info(
            f"Cough indicators: ratio={cough_ratio:.3f}, freq={cough_freq_ratio:.3f}, "
            f"harsh={harsh_ratio:.3f}, onset={onset_rate:.3f}, energy_var={energy_var:.3f}"
        )

        # --------------------------------------------------------------
        # Compose final 120-D feature vector
        # --------------------------------------------------------------
        basic = np.array([
            features["rms_energy"],
            features["zero_crossing_rate"],
            features["spectral_rolloff"],
            features["spectral_centroid"],
            cough_ratio,
            cough_freq_ratio,
            harsh_ratio,
            onset_rate,
            energy_var,
            signal_strength,
        ])

        combined = np.concatenate([opensmile_features, basic])
        if len(combined) < 120:
            combined = np.pad(combined, (0, 120 - len(combined)), constant_values=0)
        elif len(combined) > 120:
            combined = combined[:120]

        features["model_features"] = (combined - np.mean(combined)) / (np.std(combined) + 1e-6)
        features["n_features"] = 120
        features["transcription"] = ""

        return features

    except Exception as e:
        logger.error(f"Feature extraction failed: {e}")
        raise


# ---------------------------------------------------------------------
# 🤖 HEURISTIC DETECTION
# ---------------------------------------------------------------------
def is_benign(features: Dict[str, Any]) -> bool:
    """Checks if input indicates normal breathing."""
    return (
        features.get("cough_event_ratio", 0) < 0.05 and
        features.get("cough_frequency_ratio", 0) < 1.0 and
        features.get("energy_variation", 0) < 1.0 and
        features.get("signal_strength", 0) < 0.005
    )


def detect_input_type(features: Dict[str, Any]) -> str:
    """
    Simplified and stable heuristic classifier.
    Prioritizes accuracy and low false positives.
    """
    c = features.get("cough_event_ratio", 0)
    f = features.get("cough_frequency_ratio", 0)
    e = features.get("energy_variation", 0)
    o = features.get("onset_rate", 0)
    h = features.get("harsh_sound_ratio", 0)

    logger.info(f"Detecting type: cough={c:.3f}, freq={f:.3f}, energy={e:.3f}, onset={o:.3f}, harsh={h:.3f}")

    # --- COUGH: strong burst ---
    if e > 2.5 and h > 0.12:
        logger.info("🤧 Detected: cough")
        return "cough"

    # --- THROAT CLEARING: medium energy + fast onset ---
    if 1.0 < e <= 2.5 and 0.05 <= h <= 0.12 and o > 2.0:
        logger.info("🗣️ Detected: throat_clearing")
        return "throat_clearing"

    # --- HEAVY BREATHING: very high energy sustained ---
    if e > 4.5 and o < 1.5 and h < 0.08:
        logger.info("🌬️ Detected: heavy_breathing")
        return "heavy_breathing"

    # --- DEFAULT ---
    logger.info("✅ Detected: normal")
    return "normal"


def detect_task_type(y: np.ndarray, sr: int = 16000) -> str:
    """
    Automatically classify whether the input is speech or breath.
    Uses energy, zero-crossing rate, and onset stats.
    """
    try:
        rms = librosa.feature.rms(y=y)[0]
        zcr = librosa.feature.zero_crossing_rate(y)[0]
        energy_var = np.std(rms) / (np.mean(rms) + 1e-8)
        onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units="frames")
        onset_rate = len(onset_frames) / (len(y) / sr)

        if energy_var > 0.8 or onset_rate > 1.5:
            logger.info(f"🌬️ Detected cough-like sound (energy={energy_var:.2f}, onset={onset_rate:.2f}) → breath")
            return "breath"

        voiced_ratio = np.mean(rms > np.mean(rms) * 1.2)
        zcr_mean = np.mean(zcr)

        if voiced_ratio > 0.4 and zcr_mean > 0.15 and voiced_ratio < 0.85:
            logger.info(f"🗣️ Detected probable speech (voiced_ratio={voiced_ratio:.2f}, zcr={zcr_mean:.3f})")
            return "speech"
        else:
            logger.info(f"🌬️ Detected probable breath (voiced_ratio={voiced_ratio:.2f}, zcr={zcr_mean:.3f})")
            return "breath"

    except Exception as e:
        logger.warning(f"Task-type detection failed, defaulting to breath: {e}")
        return "breath"
