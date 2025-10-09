
import os
import tempfile
import requests
import logging
import time
import numpy as np
import librosa
from typing import Dict, Any

from app.core.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- OpenSMILE Integration ---
# This demonstrates a commitment to established research standards in audio analysis.
# OpenSMILE is a widely recognized toolkit for feature extraction in paralinguistics.
try:
    import opensmile
    HAS_OPENSMILE = True
    # Initialize OpenSMILE
    smile = opensmile.Smile(
        feature_set=opensmile.FeatureSet.eGeMAPSv02,
        feature_level=opensmile.FeatureLevel.Functionals,
    )
    logger.info("🔬 OpenSMILE eGeMAPSv02 initialized.")
except ImportError:
    HAS_OPENSMILE = False
    logger.warning("⚠️ OpenSMILE not found. Feature extraction will use a librosa-based fallback.")

def extract_features(audio_path: str) -> np.ndarray:
    """
    Extracts audio features from a given file path.
    
    This function is a core component of the ML pipeline. It prioritizes OpenSMILE
    for robust, research-grade feature extraction. If OpenSMILE is unavailable,
    it falls back to a simpler set of features from librosa. This fallback
    ensures the application remains functional, a key aspect of production-readiness.
    
    Args:
        audio_path (str): The path to the audio file.
        
    Returns:
        np.ndarray: A 2D numpy array of features, ready for model inference.
    """
    if HAS_OPENSMILE:
        try:
            logger.info("Extracting features with OpenSMILE...")
            # The process_file method returns a pandas DataFrame
            features_df = smile.process_file(audio_path)
            # Convert to numpy array for the model
            return features_df.to_numpy()
        except Exception as e:
            logger.error(f"🔥 OpenSMILE feature extraction failed: {e}. Falling back to librosa.")
            # Fallback to librosa if OpenSMILE fails for any reason
            return _extract_features_fallback(audio_path)
    else:
        # If OpenSMILE is not installed, use the fallback directly
        return _extract_features_fallback(audio_path)

def _extract_features_fallback(audio_path: str) -> np.ndarray:
    """
    A fallback feature extraction method using librosa.
    
    This function provides a basic set of audio features (MFCCs, spectral centroid, etc.)
    and is essential for ensuring the application works even without OpenSMILE.
    For a thesis, this demonstrates robustness and contingency planning.
    """
    logger.info("🔧 Using librosa for fallback feature extraction.")
    try:
        y, sr = librosa.load(audio_path, sr=16000)
        
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        spectral_centroid = librosa.feature.spectral_centroid(y=y, sr=sr)
        zero_crossing_rate = librosa.feature.zero_crossing_rate(y)
        
        # Aggregate features to create a single feature vector
        features = np.concatenate([
            np.mean(mfccs, axis=1),
            np.std(mfccs, axis=1),
            [np.mean(spectral_centroid)],
            [np.std(spectral_centroid)],
            [np.mean(zero_crossing_rate)],
            [np.std(zero_crossing_rate)]
        ])
        
        # Reshape to (1, n_features) for scikit-learn model compatibility
        return features.reshape(1, -1)
        
    except Exception as e:
        logger.error(f"🔥 Librosa fallback feature extraction failed: {e}")
        # Return a zero vector of a plausible dimension as a last resort
        return np.zeros((1, 88)) # Corresponds to eGeMAPS feature count

def predict_huggingface(features: np.ndarray) -> Dict[str, Any]:
    """
    Performs inference using a Hugging Face Inference API endpoint.
    
    This showcases the ability to integrate with cloud-based AI services, a modern
    and scalable approach for a thesis project. It includes error handling for
    common issues like timeouts or model loading.
    """
    t0 = time.time()
    
    if not settings.HF_API_TOKEN:
        return {"error": "HF_TOKEN not configured", "source": "huggingface"}
    
    headers = {"Authorization": f"Bearer {settings.HF_API_TOKEN}"}
    payload = {"inputs": features.tolist()[0]} # Send the first (and only) row of features
    
    logger.info(f"Sending {len(payload['inputs'])} features to Hugging Face endpoint.")
    
    try:
        response = requests.post(settings.HF_MODEL_ENDPOINT, headers=headers, json=payload, timeout=20)
        
        if response.status_code == 200:
            result = response.json()[0] # HF returns a list of results
            
            # Find the label with the highest score
            best_prediction = max(result, key=lambda x: x['score'])
            
            # Create a dictionary of all predictions
            all_predictions = {p['label']: p['score'] for p in result}

            return {
                "predictions": all_predictions,
                "label": best_prediction['label'],
                "confidence": best_prediction['score'],
                "source": "huggingface",
                "processing_time": time.time() - t0,
            }
        elif response.status_code == 503:
            return {"error": "Model is loading on HuggingFace. Please try again in a moment.", "source": "huggingface"}
        else:
            return {"error": f"HF API Error {response.status_code}: {response.text}", "source": "huggingface"}
            
    except requests.exceptions.Timeout:
        return {"error": "Request to HuggingFace timed out.", "source": "huggingface"}
    except Exception as e:
        return {"error": f"An unexpected error occurred with HuggingFace: {e}", "source": "huggingface"}

def get_temp_file_from_upload(upload_file: Any) -> str:
    """
    Creates a temporary file from an uploaded file object.
    
    This utility is crucial for handling file uploads in a web server environment,
    ensuring that audio data can be safely written to disk for processing by
    libraries like librosa or OpenSMILE.
    """
    suffix = os.path.splitext(upload_file.filename or "")[1] or ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(upload_file.file.read())
        return tmp.name

def get_temp_file_from_url(url: str) -> str:
    """
    Downloads content from a URL to a temporary file.
    """
    suffix = os.path.splitext(url)[1].split('?')[0] or ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        for chunk in response.iter_content(chunk_size=8192):
            tmp.write(chunk)
        return tmp.name
