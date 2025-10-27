"""
Feature extraction module for audio analysis.
Uses OpenSMILE for breath analysis and Whisper for speech analysis.
"""
import os
import logging
import numpy as np
from typing import Dict, Any, Union
from pathlib import Path
import librosa

logger = logging.getLogger(__name__)

# Initialize feature extractors with error handling
smile = None
whisper = None

try:
    import opensmile
    smile = opensmile.Smile(
        feature_set=opensmile.FeatureSet.eGeMAPSv02,
        feature_level=opensmile.FeatureLevel.Functionals,
    )
    logger.info(" OpenSMILE initialized with eGeMAPSv02 feature set")
except Exception as e:
    logger.warning(f"Failed to load OpenSMILE: {e}")

try:
    from transformers import pipeline
    import warnings
    warnings.filterwarnings("ignore", category=FutureWarning, module="transformers")
    
    # Check for torch availability
    try:
        import torch
        has_torch = True
    except ImportError:
        has_torch = False
    
    # Initialize Whisper for speech analysis with fallback options
    whisper = None
    try:
        # Try to initialize Whisper tiny model first
        device_map = "auto" if (has_torch and torch.cuda.is_available()) else "cpu"
        whisper = pipeline(
            "automatic-speech-recognition",
            model="openai/whisper-tiny",
            chunk_length_s=30,
            device=device_map
        )
        logger.info("✓ Whisper tiny model initialized successfully")
    except Exception as e1:
        try:
            # Fallback to base model
            whisper = pipeline(
                "automatic-speech-recognition",
                model="openai/whisper-base",
                chunk_length_s=30,
                device="cpu"
            )
            logger.info("✓ Whisper base model initialized as fallback")
        except Exception as e2:
            logger.warning(f"Failed to load Whisper models: tiny={e1}, base={e2}")
            logger.info(" Speech analysis will work without transcription")
            whisper = None
            
except ImportError:
    logger.warning("Transformers library not available - speech transcription disabled")
    whisper = None
except Exception as e:
    logger.warning(f"Failed to initialize Whisper: {e}")
    whisper = None

def extract_features(source: Union[str, Path, np.ndarray], task_type: str = "breath", sr: int = 16000) -> Dict[str, Any]:
    """
    Extract features from audio input based on task type.
    Accepts either a file path (str/Path) or a raw waveform (np.ndarray).
    Uses OpenSMILE features but ensures exactly 120 features for the model.
    
    Args:
        source: Path to normalized audio file (16kHz mono WAV) or a waveform array
        task_type: Type of analysis ("breath" or "speech")
        sr: Sample rate to assume when source is a waveform array
    
    Returns:
        Dict containing extracted features
    """
    features = {}
    
    try:
        # Determine input type and obtain waveform y and sample rate sr
        y: np.ndarray
        input_type = None
        if isinstance(source, (str, Path)):
            input_type = "file"
            file_path = str(source)
            y, sr = librosa.load(file_path, sr=16000)
        elif isinstance(source, np.ndarray):
            input_type = "array"
            y = source.astype(np.float32)
            # sr is provided via argument when array is passed
        else:
            raise ValueError(f"Unsupported audio source type: {type(source)}")

        logger.info(f"extract_features received {input_type} input (sr={sr})")
        # --- Noise Floor Check ---
        rms = np.mean(librosa.feature.rms(y=y))
        if rms > 0.1:
            logger.info(f"🌬️ High background RMS ({rms:.3f}) detected – reducing abnormal sensitivity.")
            y = y / (1 + (rms * 5))  # normalize loud backgrounds

        # Extract OpenSMILE features
        if 'file_path' in locals() and os.path.isfile(file_path):
            smile_features = smile.process_file(file_path)
        else:
            # If we don't have a file path (array input), approximate by processing from memory
            # OpenSMILE expects a file; create a temporary in-memory WAV buffer if needed
            import soundfile as sf
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
                sf.write(tmp.name, y, sr)
                smile_features = smile.process_file(tmp.name)
        # Flatten OpenSMILE features to 1D array
        opensmile_features = smile_features.values.flatten()
        logger.info(f"OpenSMILE features shape: {opensmile_features.shape}")
        
        # Basic audio features to complement OpenSMILE
        features["duration"] = len(y) / sr
        features["rms_energy"] = np.sqrt(np.mean(y**2))
        features["zero_crossing_rate"] = np.mean(librosa.feature.zero_crossing_rate(y))
        
        # Task-specific feature weighting to make breath and speech features different
        task_weight = 1.0 if task_type == "breath" else 1.5  # Amplify speech features
        
        # Spectral features with task-specific weighting
        mel_spec = librosa.feature.melspectrogram(y=y, sr=sr)
        features["spectral_rolloff"] = np.mean(librosa.feature.spectral_rolloff(S=mel_spec)) * task_weight
        features["spectral_centroid"] = np.mean(librosa.feature.spectral_centroid(S=mel_spec)) * task_weight
        
        # Additional features to reach exactly 120 features with task-specific variations
        additional_features = []
        
        # Task-specific spectral emphasis
        if task_type == "speech":
            # For speech, emphasize higher frequencies and formant-related features
            spectral_bandwidth = np.mean(librosa.feature.spectral_bandwidth(y=y, sr=sr)) * 1.2
            additional_features.append(spectral_bandwidth)
            
            # Chroma features (12 features) - more important for speech
            chroma = librosa.feature.chroma_stft(y=y, sr=sr)
            chroma_mean = np.mean(chroma, axis=1) * 1.3
            additional_features.extend(chroma_mean)
            
            # Tonnetz features (6 features) - harmonic relationships in speech
            tonnetz = librosa.feature.tonnetz(y=y, sr=sr)
            tonnetz_mean = np.mean(tonnetz, axis=1) * 1.4
            additional_features.extend(tonnetz_mean)
            
            # MFCC features (13 features) - crucial for speech
            mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
            mfcc_mean = np.mean(mfcc, axis=1) * 1.1
            additional_features.extend(mfcc_mean)
        else:
            # For breath analysis, focus on different aspects
            spectral_bandwidth = np.mean(librosa.feature.spectral_bandwidth(y=y, sr=sr))
            additional_features.append(spectral_bandwidth)
            
            # Chroma features (12 features) - less weighted for breath
            chroma = librosa.feature.chroma_stft(y=y, sr=sr)
            chroma_mean = np.mean(chroma, axis=1) * 0.8
            additional_features.extend(chroma_mean)
            
            # Tonnetz features (6 features)
            tonnetz = librosa.feature.tonnetz(y=y, sr=sr)
            tonnetz_mean = np.mean(tonnetz, axis=1)
            additional_features.extend(tonnetz_mean)
            
            # MFCC features (13 features) - standard for breath
            mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
            mfcc_mean = np.mean(mfcc, axis=1)
            additional_features.extend(mfcc_mean)
        
        # Convert to numpy array
        additional_features = np.array(additional_features)
        logger.info(f"Additional features shape: {additional_features.shape}")
        
        # Enhanced cough detection and distance-aware features
        y_normalized = y / (np.max(np.abs(y)) + 1e-8)  # Normalize for distance variations
        
        # Detect potential cough events (sudden amplitude spikes)
        energy_envelope = librosa.feature.rms(y=y, frame_length=512, hop_length=256)[0]
        energy_threshold = np.mean(energy_envelope) + 2 * np.std(energy_envelope)
        cough_events = energy_envelope > energy_threshold
        cough_ratio = np.sum(cough_events) / len(cough_events)
        
        # Spectral features optimized for cough detection
        freqs = librosa.fft_frequencies(sr=sr)
        stft = np.abs(librosa.stft(y))
        
        # Frequency band energies (normalized by total energy)
        total_energy = np.mean(stft) + 1e-8
        low_freq_energy = np.mean(stft[freqs <= 500]) / total_energy
        mid_freq_energy = np.mean(stft[(freqs > 500) & (freqs <= 2000)]) / total_energy
        high_freq_energy = np.mean(stft[freqs > 2000]) / total_energy
        
        # Cough-specific frequency ratios
        cough_freq_ratio = mid_freq_energy / (low_freq_energy + 1e-8)
        harsh_sound_ratio = high_freq_energy / (low_freq_energy + 1e-8)
        
        # Temporal features for cough detection
        onset_frames = librosa.onset.onset_detect(y=y, sr=sr, units='frames')
        onset_rate = len(onset_frames) / (len(y) / sr)  # Onsets per second
        
        # Roughness and irregularity measures
        roughness = np.std(np.diff(y_normalized))
        energy_variation = np.std(energy_envelope) / (np.mean(energy_envelope) + 1e-8)
        
        # Distance/volume normalization features
        signal_strength = np.mean(np.abs(y))  # Overall signal strength
        dynamic_range = np.max(y) - np.min(y)  # Signal dynamic range
        snr_estimate = signal_strength / (np.std(y[np.abs(y) < 0.1 * np.max(np.abs(y))]) + 1e-8)
        
        basic_features = np.array([
            features["rms_energy"] * task_weight,
            features["zero_crossing_rate"] * task_weight, 
            features["spectral_rolloff"],
            features["spectral_centroid"],
            # Enhanced cough detection features
            cough_ratio,  # Ratio of potential cough events
            cough_freq_ratio,  # Mid/low frequency ratio (high in coughs)
            harsh_sound_ratio,  # High/low frequency ratio (harsh sounds)
            onset_rate * task_weight,  # Rate of sound onsets (bursts)
            roughness * task_weight,  # Signal roughness
            energy_variation,  # Energy variability
            # Distance/volume features
            signal_strength * task_weight,  # Overall signal strength
            dynamic_range,  # Signal dynamic range
            snr_estimate,  # Estimated signal-to-noise ratio
        ])
        logger.info(f"Basic features shape: {basic_features.shape}")
        
        # Additional spectral features for robustness
        spectral_contrast = np.mean(librosa.feature.spectral_contrast(y=y, sr=sr), axis=1)
        spectral_flatness = np.mean(librosa.feature.spectral_flatness(y=y))
        
        cough_features = np.array([
            low_freq_energy,
            mid_freq_energy, 
            high_freq_energy,
            spectral_flatness,  # Measure of spectral peakiness (low in coughs)
            np.mean(spectral_contrast),  # Average spectral contrast
        ])
        
        # Log cough detection indicators for debugging
        if cough_ratio > 0.3 or cough_freq_ratio > 2.0:
            logger.info(f"Potential cough indicators detected:")
            logger.info(f"   - Cough event ratio: {cough_ratio:.3f}")
            logger.info(f"   - Cough frequency ratio: {cough_freq_ratio:.3f}")
            logger.info(f"   - Onset rate: {onset_rate:.3f} Hz")
            logger.info(f"   - Signal strength: {signal_strength:.6f}")
        
        # Store cough indicators in features dict for analysis service
        features["cough_event_ratio"] = cough_ratio
        features["cough_frequency_ratio"] = cough_freq_ratio
        features["harsh_sound_ratio"] = harsh_sound_ratio
        features["onset_rate"] = onset_rate
        features["energy_variation"] = energy_variation
        features["signal_strength"] = signal_strength

        # Log cough detection indicators for debugging (lowered thresholds)
        if cough_ratio > 0.1 or cough_freq_ratio > 1.2 or energy_variation > 0.5:
            logger.info(f"Potential cough indicators detected:")
            logger.info(f"   - Cough event ratio: {cough_ratio:.3f} (threshold: >0.1)")
            logger.info(f"   - Cough frequency ratio: {cough_freq_ratio:.3f} (threshold: >1.2)")
            logger.info(f"   - Harsh sound ratio: {harsh_sound_ratio:.3f}")
            logger.info(f"   - Onset rate: {onset_rate:.3f} Hz")
            logger.info(f"   - Energy variation: {energy_variation:.3f} (threshold: >0.5)")
            logger.info(f"   - Signal strength: {signal_strength:.6f}")
        else:
            logger.info(f"Cough indicators (below threshold):")
            logger.info(f"   - Cough event ratio: {cough_ratio:.3f}")
            logger.info(f"   - Cough frequency ratio: {cough_freq_ratio:.3f}")
            logger.info(f"   - Energy variation: {energy_variation:.3f}")

        # Combine all basic features
        basic_features = np.concatenate([basic_features, cough_features])
        logger.info(f"Enhanced basic features shape: {basic_features.shape}")
        
        # Combine OpenSMILE with additional features
        try:
            combined_features = np.concatenate([
                opensmile_features,
                additional_features,
                basic_features
            ])
            logger.info(f"Combined features shape: {combined_features.shape}")
        except Exception as e:
            logger.error(f"Error concatenating features: {e}")
            # Fallback: just use OpenSMILE features and pad
            combined_features = opensmile_features
        
        # Ensure exactly 120 features with better distribution
        if len(combined_features) > 120:
            # Intelligently select the most important features instead of truncating
            # Keep OpenSMILE features (most important) + some additional features
            opensmile_count = min(88, len(opensmile_features))
            additional_count = min(32, len(additional_features))
            
            model_features = np.concatenate([
                opensmile_features[:opensmile_count],
                additional_features[:additional_count]
            ])
            
            # Fill remaining slots with basic features if needed
            remaining_slots = 120 - len(model_features)
            if remaining_slots > 0 and len(basic_features) > 0:
                basic_count = min(remaining_slots, len(basic_features))
                model_features = np.concatenate([
                    model_features,
                    basic_features[:basic_count]
                ])
            
            # If still not 120, pad only the minimum needed
            if len(model_features) < 120:
                padding = 120 - len(model_features)
                model_features = np.pad(model_features, (0, padding), mode='constant', constant_values=0)
            else:
                model_features = model_features[:120]
                
        elif len(combined_features) < 120:
            # Pad with small random noise instead of zeros to avoid model seeing identical inputs
            padding = 120 - len(combined_features)
            noise_padding = np.random.normal(0, 0.001, padding)  # Small noise
            model_features = np.concatenate([combined_features, noise_padding])
        else:
            model_features = combined_features
        
        # Normalize features to ensure they're in a reasonable range
        model_features = np.nan_to_num(model_features, nan=0.0, posinf=1.0, neginf=-1.0)
            
        logger.info(f"Final model features shape: {model_features.shape}")
        
        # Store the exactly 120 features for the model
        features["model_features"] = model_features
        features["opensmile"] = opensmile_features  # Keep original for debugging
        features["n_features"] = len(model_features)
        
        if task_type == "speech":
            # Add speech recognition for speech tasks with robust error handling
            try:
                if whisper is not None and isinstance(source, (str, Path)):
                    logger.info("Starting speech transcription...")
                    transcription = whisper(str(source))
                    features["transcription"] = transcription["text"]
                    logger.info(f"✓ Speech transcription successful: {transcription['text'][:100]}...")
                else:
                    logger.warning(" Whisper model not available or source not a file, skipping transcription")
                    features["transcription"] = "Speech analysis unavailable - transcription model not loaded"
            except Exception as e:
                logger.error(f"Speech recognition failed: {e}")
                # Provide fallback for speech analysis
                features["transcription"] = f"Speech transcription failed: {str(e)}"
                # Don't let speech recognition failure break the entire analysis
        else:
            features["transcription"] = ""
        
        # Normalize feature magnitudes for stable thresholds
        features['model_features'] = np.array(features['model_features'])
        features['model_features'] = (features['model_features'] - np.mean(features['model_features'])) / (np.std(features['model_features']) + 1e-6)

        
        return features

    except Exception as e:
        logger.error(f"Feature extraction failed: {e}")
        raise


def is_benign(features: Dict[str, Any]) -> bool:
    """
    Check if audio features indicate benign/normal breathing patterns.
    Returns True if features suggest healthy breathing, False if potentially pathological.
    """
    cough_event_ratio = features.get("cough_event_ratio", 0.0)
    cough_frequency_ratio = features.get("cough_frequency_ratio", 0.0)
    energy_variation = features.get("energy_variation", 0.0)
    signal_strength = features.get("signal_strength", 0.0)

    # Stricter benign thresholds to avoid overriding model predictions for coughs/heavy breathing
    return (
        cough_event_ratio < 0.05 and       # Very low cough event ratio
        cough_frequency_ratio < 1.0 and     # Low frequency ratio
        energy_variation < 1.0 and          # Low energy variation
        signal_strength < 0.005             # Very low signal strength (quiet/normal recording)
    )
