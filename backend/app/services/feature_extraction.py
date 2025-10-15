"""
Feature extraction module for audio analysis.
Uses OpenSMILE for breath analysis and Whisper for speech analysis.
"""
import os
import logging
import numpy as np
from typing import Dict, Any
import opensmile
from transformers import pipeline
import librosa

logger = logging.getLogger(__name__)

# Initialize feature extractors
smile = opensmile.Smile(
    feature_set=opensmile.FeatureSet.ComParE_2016,
    feature_level=opensmile.FeatureLevel.Functionals,
)

try:
    # Initialize Whisper for speech analysis (fallback to small model if needed)
    whisper = pipeline(
        "automatic-speech-recognition",
        model="openai/whisper-small",
        chunk_length_s=30,
    )
except Exception as e:
    logger.warning(f"Failed to load Whisper model: {e}")
    whisper = None

def extract_features(file_path: str, task_type: str = "breath") -> Dict[str, Any]:
    """
    Extract features from audio file based on task type.
    
    Args:
        file_path: Path to normalized audio file (16kHz mono WAV)
        task_type: Type of analysis ("breath" or "speech")
    
    Returns:
        Dict containing extracted features
    """
    features = {}
    
    try:
        # Load audio with librosa for basic features
        y, sr = librosa.load(file_path, sr=16000)
        
        # Extract OpenSMILE features
        smile_features = smile.process_file(file_path)
        features["opensmile"] = smile_features.values
        
        # Basic audio features
        features["duration"] = len(y) / sr
        features["rms_energy"] = np.sqrt(np.mean(y**2))
        features["zero_crossing_rate"] = np.mean(librosa.feature.zero_crossing_rate(y))
        
        # Spectral features
        mel_spec = librosa.feature.melspectrogram(y=y, sr=sr)
        features["spectral_rolloff"] = np.mean(librosa.feature.spectral_rolloff(S=mel_spec))
        features["spectral_centroid"] = np.mean(librosa.feature.spectral_centroid(S=mel_spec))
        
        if task_type == "speech" and whisper is not None:
            # Add speech recognition for speech tasks
            try:
                transcription = whisper(file_path)
                features["transcription"] = transcription["text"]
            except Exception as e:
                logger.warning(f"Speech recognition failed: {e}")
                features["transcription"] = ""
        
        return features
        
    except Exception as e:
        logger.error(f"Feature extraction failed: {e}")
        raise
