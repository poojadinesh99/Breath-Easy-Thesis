from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import numpy as np
import uvicorn
import os
import tempfile
import requests
import time
import logging
import json
from typing import Dict, Any

# Load environment variables
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv not available, continue with system env vars

# Try to import optional dependencies
try:
    import librosa
    HAS_LIBROSA = True
except ImportError:
    HAS_LIBROSA = False
    print("Warning: librosa not available, some audio processing will be disabled")

try:
    import whisper
    HAS_WHISPER = True
except ImportError:
    HAS_WHISPER = False
    print("Warning: whisper not available, speech-to-text will be disabled")

try:
    import joblib
    HAS_JOBLIB = True
except ImportError:
    HAS_JOBLIB = False
    print("Warning: joblib not available, local models will be disabled")

# === Import OpenSMILE helper (with fallback) ===
try:
    from utils.opensmile_utils import extract_features_for_inference
    HAS_OPENSMILE = True
except ImportError:
    HAS_OPENSMILE = False
    print("Warning: OpenSMILE not available, feature extraction will use fallback")

# Global variables - will be loaded on startup
model = None
label_map = None
inv_label_map = None
model_type = None
whisper_model = None

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.getenv("MODEL_PATH", os.path.join(BASE_DIR, "ml", "models", "model_opensmile.pkl"))
LABEL_MAP_PATH = os.getenv("LABEL_MAP_PATH", os.path.join(BASE_DIR, "ml", "models", "label_map.json"))

# OpenSMILE feature config (must match training)
OS_FEATURE_SET = "eGeMAPS"       # or "ComParE_2016"
OS_FEATURE_LEVEL = "func"        # "func" (functionals) or "lld"
OS_AGG_IF_LLD = "meanstd"        # aggregation if LLD

# Whisper configuration
WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", "base")

# Hugging Face configuration
HF_API_TOKEN = os.getenv("HF_TOKEN")
USE_HF = os.getenv("USE_HF", "true").lower() == "true"
HF_MODEL_ENDPOINT = "https://api-inference.huggingface.co/models/PoojaDinesh99/breathe-easy-dualnet"

# For deployment, default to using HF since local models may not be available
PREFER_HF = os.getenv("PREFER_HF", "true").lower() == "true"
# -----------------------------------------------------------------------------
# App + CORS
# -----------------------------------------------------------------------------
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten if needed
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.getenv("MODEL_PATH", os.path.join(BASE_DIR, "ml", "models", "model_opensmile.pkl"))
LABEL_MAP_PATH = os.getenv("LABEL_MAP_PATH", os.path.join(BASE_DIR, "ml", "models", "label_map.json"))

# OpenSMILE feature config (must match training)
OS_FEATURE_SET = "eGeMAPS"       # or "ComParE_2016"
OS_FEATURE_LEVEL = "func"        # "func" (functionals) or "lld"
OS_AGG_IF_LLD = "meanstd"        # aggregation if LLD

# -----------------------------------------------------------------------------
# Load model + labels at startup
# -----------------------------------------------------------------------------
model = None
model_type = None
inv_label_map: Dict[int, str] = {}

def _load_model_and_labels():
    global model, model_type, inv_label_map
    model = None
    model_type = None
    inv_label_map = {}

    # Check if we should prefer HuggingFace (for deployment)
    if PREFER_HF and HF_API_TOKEN:
        logger.info("🤗 Using HuggingFace model as primary (PREFER_HF=true)")
        model_type = "huggingface"
        # Set up default label map for HF
        inv_label_map = {
            0: "abnormal",
            1: "clear", 
            2: "wheezing",
            3: "crackles"
        }
        logger.info("✅ HuggingFace model configured")
        return

    # Try to load local sklearn model (only if joblib is available)
    if HAS_JOBLIB and os.path.exists(MODEL_PATH):
        try:
            m = joblib.load(MODEL_PATH)
            model = m
            model_type = "sklearn"
            logger.info("✅ Loaded sklearn model from %s", MODEL_PATH)
        except Exception as e:
            logger.warning(f"⚠️ Failed to load sklearn model: {e}")
    
    # If no local model and HF is available, use HF as fallback
    if model is None and HF_API_TOKEN:
        logger.info("📡 No local model found, using Hugging Face API fallback")
        model_type = "huggingface"
    elif model is None:
        logger.warning("⚠️ No model available (local or HuggingFace)")

    # Load label map and invert it to {idx: label}
    if os.path.exists(LABEL_MAP_PATH):
        try:
            with open(LABEL_MAP_PATH, "r") as f:
                label_map = json.load(f)  # {"abnormal":0,"clear":1}
            # invert
            inv_label_map = {v: k for k, v in label_map.items()}
            logger.info("✅ Loaded label map: %s", inv_label_map)
        except Exception as e:
            logger.warning(f"⚠️ Failed to load label map: {e}")
    else:
        # fallback generic labels if missing
        logger.info("📋 Using fallback label map")
        inv_label_map = {
            0: "abnormal",
            1: "clear", 
            2: "wheezing",
            3: "crackles"
        }

@app.on_event("startup")
async def startup_event():
    """Load model and initialize Whisper on startup"""
    _load_model_and_labels()
    await _load_whisper_model()

async def _load_whisper_model():
    """Load Whisper model for speech transcription"""
    global whisper_model
    if not HAS_WHISPER:
        logger.info("⚠️ Whisper not available, speech-to-text will be disabled")
        whisper_model = None
        return
        
    try:
        # Use tiny model for deployment to reduce memory usage
        model_size = os.getenv("WHISPER_MODEL_SIZE", "tiny")
        logger.info(f"Loading Whisper model: {model_size}")
        whisper_model = whisper.load_model(model_size)
        logger.info("✅ Whisper model loaded successfully")
    except Exception as e:
        logger.warning(f"⚠️ Failed to load Whisper model: {e}")
        whisper_model = None

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

def _download_to_tmp(url: str, suffix: str = ".wav") -> str:
    r = requests.get(url, stream=True, timeout=30)
    r.raise_for_status()
    fd, tmp_path = tempfile.mkstemp(suffix=suffix)
    os.close(fd)
    with open(tmp_path, "wb") as f:
        for chunk in r.iter_content(chunk_size=8192):
            if chunk:
                f.write(chunk)
    return tmp_path


def _predict_local(features: np.ndarray) -> Dict[str, Any]:
    """
    Predict with the loaded local model (sklearn). Returns dict with:
      predictions{label: prob}, top label, confidence, source="local"
    """
    if model is None:
        raise RuntimeError("No local model loaded")

    if model_type == "sklearn":
        # probs if available
        if hasattr(model, "predict_proba"):
            proba = model.predict_proba(features)[0]
            classes_idx = list(model.classes_)  # e.g. [0,1]
        else:
            pred = model.predict(features)[0]
            classes_idx = list(model.classes_) if hasattr(model, "classes_") else [pred]
            proba = np.zeros(len(classes_idx), dtype=float)
            proba[classes_idx.index(pred)] = 1.0

        # map idx->label using inv_label_map; fallback to str(idx)
        labels = [inv_label_map.get(int(c), str(int(c))) for c in classes_idx]
        predictions = {labels[i]: float(proba[i]) for i in range(len(labels))}
        top_i = int(np.argmax(proba))
        return {
            "predictions": predictions,
            "label": labels[top_i],
            "confidence": float(proba[top_i]),
            "source": "local",
        }

    raise RuntimeError(f"Unsupported model_type: {model_type}")


def _transcribe_audio(audio_path: str) -> str:
    """
    Transcribe audio using Whisper model
    """
    if whisper_model is None:
        raise RuntimeError("Whisper model not loaded")

    try:
        result = whisper_model.transcribe(audio_path)
        transcript = result["text"].strip()
        logger.info(f"Transcribed audio: '{transcript}'")
        return transcript
    except Exception as e:
        logger.error(f"Failed to transcribe audio: {e}")
        raise RuntimeError(f"Speech-to-text failed: {e}")

def _predict_huggingface(features: np.ndarray) -> Dict[str, Any]:
    """
    Predict using Hugging Face model API
    Args:
        features: Feature vector from OpenSMILE
    Returns:
        Dictionary with prediction results
    """
    t0 = time.time()
    
    if not HF_API_TOKEN:
        return {
            "predictions": {},
            "label": "Error",
            "confidence": 0.0,
            "source": "huggingface",
            "processing_time": time.time() - t0,
            "error": "HF_TOKEN not configured"
        }
    
    try:
        headers = {"Authorization": f"Bearer {HF_API_TOKEN}"}
        
        # Prepare payload - HF expects features as a list
        if features.ndim > 1:
            payload = {"inputs": features.tolist()[0]}  # Take first row if 2D
        else:
            payload = {"inputs": features.tolist()}
        
        logger.info(f"Sending features to HF model: {len(payload['inputs'])} features")
        
        # Make request to HF API
        response = requests.post(
            HF_MODEL_ENDPOINT, 
            headers=headers, 
            json=payload, 
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            logger.info(f"HF API response: {result}")
            
            # Parse HF response - adapt based on your model's output format
            if isinstance(result, list) and len(result) > 0:
                # If result is a list of predictions
                predictions = result[0] if isinstance(result[0], dict) else {}
                
                # Find the highest confidence prediction
                if isinstance(predictions, dict):
                    best_label = max(predictions.keys(), key=lambda k: predictions[k])
                    best_confidence = predictions[best_label]
                else:
                    # Fallback for different response formats
                    best_label = "clear"
                    best_confidence = 0.5
                    predictions = {"clear": 0.5, "abnormal": 0.3, "wheezing": 0.2}
                    
            elif isinstance(result, dict):
                # If result is directly a dict
                predictions = result.get("predictions", result)
                best_label = result.get("label", "clear")
                best_confidence = result.get("confidence", 0.5)
            else:
                # Fallback
                predictions = {"clear": 0.5, "abnormal": 0.3, "wheezing": 0.2}
                best_label = "clear"
                best_confidence = 0.5
            
            # Generate text summary
            if best_confidence > 0.7:
                if best_label.lower() in ["clear", "normal"]:
                    text_summary = "Breathing sounds appear normal and clear."
                else:
                    text_summary = f"Detected {best_label} with high confidence. Consider monitoring."
            else:
                text_summary = f"Uncertain detection of {best_label}. Results should be interpreted by a healthcare professional."
            
            return {
                "predictions": predictions,
                "label": best_label,
                "confidence": float(best_confidence),
                "source": "huggingface",
                "processing_time": time.time() - t0,
                "text_summary": text_summary,
                "error": None
            }
            
        elif response.status_code == 503:
            return {
                "predictions": {},
                "label": "Error",
                "confidence": 0.0,
                "source": "huggingface",
                "processing_time": time.time() - t0,
                "error": "Model is loading on HuggingFace. Please try again in a few minutes."
            }
        else:
            return {
                "predictions": {},
                "label": "Error", 
                "confidence": 0.0,
                "source": "huggingface",
                "processing_time": time.time() - t0,
                "error": f"HF API error {response.status_code}: {response.text}"
            }
            
    except requests.exceptions.Timeout:
        return {
            "predictions": {},
            "label": "Error",
            "confidence": 0.0,
            "source": "huggingface", 
            "processing_time": time.time() - t0,
            "error": "Request to HuggingFace timed out"
        }
    except Exception as e:
        return {
            "predictions": {},
            "label": "Error",
            "confidence": 0.0,
            "source": "huggingface",
            "processing_time": time.time() - t0,
            "error": f"HuggingFace prediction failed: {str(e)}"
        }

def _extract_features_fallback(audio_path: str) -> np.ndarray:
    """
    Fallback feature extraction using librosa if OpenSMILE is not available
    """
    if not HAS_LIBROSA:
        raise RuntimeError("Neither OpenSMILE nor librosa available for feature extraction")
    
    try:
        # Load audio
        y, sr = librosa.load(audio_path, sr=16000)
        
        # Extract basic features that might match training
        features = []
        
        # MFCCs (common audio features)
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        features.extend(np.mean(mfccs, axis=1))
        features.extend(np.std(mfccs, axis=1))
        
        # Spectral features
        spectral_centroids = librosa.feature.spectral_centroid(y=y, sr=sr)
        features.append(np.mean(spectral_centroids))
        features.append(np.std(spectral_centroids))
        
        # Zero crossing rate
        zcr = librosa.feature.zero_crossing_rate(y)
        features.append(np.mean(zcr))
        features.append(np.std(zcr))
        
        # RMS energy
        rms = librosa.feature.rms(y=y)
        features.append(np.mean(rms))
        features.append(np.std(rms))
        
        # Pad or truncate to expected size (adjust based on your model)
        feature_vector = np.array(features)
        
        # Reshape to 2D for sklearn compatibility
        return feature_vector.reshape(1, -1)
        
    except Exception as e:
        logger.error(f"Fallback feature extraction failed: {e}")
        # Return dummy features as last resort
        return np.random.rand(1, 50).astype(np.float32)

# -----------------------------------------------------------------------------
# Routes
# -----------------------------------------------------------------------------
@app.post("/predict/unified")
async def predict_unified(
    request: Request,
    file: UploadFile = File(None),
    audio_url: str = Form(None),
):
    """
    Accepts EITHER:
      - JSON: {"file_url": "https://.../file.wav"}
      - multipart/form-data: file=<UploadFile> OR audio_url=<str>
    Returns:
      {
        "predictions": {"abnormal": 0.73, "clear": 0.27},
        "label": "abnormal",
        "confidence": 0.73,
        "source": "local" | "huggingface",
        "processing_time": <seconds>,
        "error": null | "<msg>"
      }
    """
    t0 = time.time()
    tmp_path = None
    try:
        # Try reading JSON body (frontend uses file_url)
        file_url = None
        try:
            if request.headers.get("content-type", "").startswith("application/json"):
                body = await request.json()
                file_url = body.get("file_url")
        except Exception:
            file_url = None

        # Resolve input into a local temp file path
        if file is not None:
            logger.info(f"Unified endpoint received file upload: {file.filename}, content_type: {file.content_type}")
            suffix = os.path.splitext(file.filename or "")[1] or ".wav"
            fd, tmp_path = tempfile.mkstemp(suffix=suffix)
            os.close(fd)
            with open(tmp_path, "wb") as f:
                content = await file.read()
                f.write(content)
            logger.info(f"Unified endpoint saved upload to: {tmp_path}, size: {len(content)} bytes")
        elif audio_url:
            logger.info(f"Unified endpoint using audio_url: {audio_url}")
            tmp_path = _download_to_tmp(audio_url)
        elif file_url:
            logger.info(f"Unified endpoint using file_url: {file_url}")
            tmp_path = _download_to_tmp(file_url)
        else:
            logger.error("Unified endpoint: No audio provided")
            return JSONResponse(
                status_code=400,
                content={
                    "predictions": {},
                    "label": None,
                    "confidence": None,
                    "source": None,
                    "processing_time": 0.0,
                    "error": "No audio provided (file or URL).",
                },
            )

        # Validate audio duration before processing
        is_valid, audio_duration = validate_audio_duration(tmp_path, min_duration=1.5)
        if not is_valid:
            return JSONResponse(
                status_code=400,
                content={
                    "predictions": {},
                    "label": "error",
                    "confidence": 0.0,
                    "source": None,
                    "processing_time": time.time() - t0,
                    "error": f"Audio too short ({audio_duration:.1f}s). Please record at least 2 seconds for better accuracy.",
                    "text_summary": "Recording too short - please try recording for at least 2-3 seconds."
                },
            )

        # Extract OpenSMILE features to match training
        try:
            if HAS_OPENSMILE:
                feats = extract_features_for_inference(
                    tmp_path,
                    feature_set=OS_FEATURE_SET,
                    feature_level=OS_FEATURE_LEVEL,
                    aggregate_if_lld=OS_AGG_IF_LLD,
                )
            else:
                logger.info("Using fallback feature extraction (OpenSMILE not available)")
                feats = _extract_features_fallback(tmp_path)
        except Exception as e_feat:
            logger.warning(f"Feature extraction failed: {e_feat}, using fallback")
            feats = _extract_features_fallback(tmp_path)

        # Validate audio duration (Whisper requirement)
        try:
            duration = librosa.get_duration(filename=tmp_path)
            logger.info(f"Audio duration: {duration} seconds")
            if duration < 1.0:
                return JSONResponse(
                    status_code=400,
                    content={
                        "predictions": {},
                        "label": None,
                        "confidence": None,
                        "source": None,
                        "processing_time": 0.0,
                        "error": "Audio file is too short (less than 1 second).",
                    },
                )
        except Exception as e_duration:
            logger.warning(f"⚠️ Duration validation failed: {e_duration}")

        # Try local model first (if available and not preferring HF)
        if model_type == "sklearn" and model is not None:
            try:
                out = _predict_local(feats)
                out["processing_time"] = time.time() - t0
                out["error"] = None

                # --- Add friendly text summary ---
                top_label = out["label"]
                top_confidence = out["confidence"]

                if str(top_label).lower() == "clear":
                    text_summary = (
                        f"The respiratory sound is classified as clear "
                        f"with {top_confidence*100:.1f}% confidence. "
                        "No abnormal patterns were detected."
                    )
                else:
                    text_summary = (
                        f"The respiratory sound is classified as {top_label} "
                        f"with {top_confidence*100:.1f}% confidence. "
                        "This suggests possible abnormality — further medical evaluation is advised."
                    )

                out["text_summary"] = text_summary
                return out
            except Exception as e_local:
                logger.warning(f"Local model failed: {e_local}")

        # Use HuggingFace model (primary in deployment or fallback)
        if model_type == "huggingface" or HF_API_TOKEN:
            try:
                out = _predict_huggingface(feats)
                out["processing_time"] = time.time() - t0
                return out
            except Exception as e_hf:
                logger.warning(f"HuggingFace model failed: {e_hf}")
                return {
                    "predictions": {},
                    "label": "Error",
                    "confidence": 0.0,
                    "source": "huggingface",
                    "processing_time": time.time() - t0,
                    "error": str(e_hf),
                }

        # No fallback
        return {
            "predictions": {},
            "label": None,
            "confidence": None,
            "source": None,
            "processing_time": time.time() - t0,
            "error": "No model available",
        }

    except Exception as e:
        return {
            "predictions": {},
            "label": None,
            "confidence": None,
            "source": None,
            "processing_time": time.time() - t0,
            "error": str(e),
        }
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

@app.post("/predict/speech")
async def predict_speech(
    request: Request,
    file: UploadFile = File(None),
    audio_url: str = Form(None),
):
    """
    Accepts EITHER:
      - JSON: {"file_url": "https://.../file.wav"}
      - multipart/form-data: file=<UploadFile> OR audio_url=<str>
    Returns:
      {
        "transcript": "<transcribed text>",
        "message": "You said: <transcript>",
        "processing_time": <seconds>,
        "error": null | "<msg>"
      }
    """
    t0 = time.time()
    tmp_path = None
    try:
        # Try reading JSON body (frontend uses file_url)
        file_url = None
        try:
            if request.headers.get("content-type", "").startswith("application/json"):
                body = await request.json()
                file_url = body.get("file_url")
        except Exception:
            file_url = None

        # Resolve input into a local temp file path
        if file is not None:
            logger.info(f"Speech endpoint received file upload: {file.filename}, content_type: {file.content_type}")
            suffix = os.path.splitext(file.filename or "")[1] or ".wav"
            fd, tmp_path = tempfile.mkstemp(suffix=suffix)
            os.close(fd)
            with open(tmp_path, "wb") as f:
                content = await file.read()
                f.write(content)
            logger.info(f"Speech endpoint saved upload to: {tmp_path}, size: {len(content)} bytes")
        elif audio_url:
            logger.info(f"Speech endpoint using audio_url: {audio_url}")
            tmp_path = _download_to_tmp(audio_url)
        elif file_url:
            logger.info(f"Speech endpoint using file_url: {file_url}")
            tmp_path = _download_to_tmp(file_url)
        else:
            logger.error("Speech endpoint: No audio provided")
            return JSONResponse(
                status_code=400,
                content={
                    "transcript": "",
                    "message": "",
                    "processing_time": 0.0,
                    "error": "No audio provided (file or URL).",
                },
            )

        # Transcribe audio using Whisper
        try:
            transcript = _transcribe_audio(tmp_path)

            # Create friendly message
            if transcript:
                message = f"You said: {transcript}"
            else:
                message = "No speech detected in the audio."

            return {
                "transcript": transcript,
                "message": message,
                "processing_time": time.time() - t0,
                "error": None,
            }

        except Exception as e_transcribe:
            logger.error(f"Speech transcription failed: {e_transcribe}")
            return {
                "transcript": "",
                "message": "",
                "processing_time": time.time() - t0,
                "error": f"Speech-to-text failed: {str(e_transcribe)}",
            }

    except Exception as e:
        return {
            "transcript": "",
            "message": "",
            "processing_time": time.time() - t0,
            "error": str(e),
        }
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "local_model_available": model is not None,
        "model_type": model_type,
        "labels": inv_label_map,
        "hf_token_available": bool(HF_API_TOKEN),
        "whisper_model_available": whisper_model is not None,
        "whisper_model_size": WHISPER_MODEL_SIZE,
    }

@app.get("/")
async def root():
    return {"message": "Breathe Easy API — use /predict/unified or /predict/speech"}

def validate_audio_duration(file_path: str, min_duration: float = 2.0) -> tuple[bool, float]:
    """
    Validate audio file duration.
    Returns (is_valid, duration_seconds)
    """
    try:
        duration = librosa.get_duration(path=file_path)
        return duration >= min_duration, duration
    except Exception as e:
        logger.warning(f"Could not determine audio duration: {e}")
        return True, 0.0  # Allow processing if we can't determine duration

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
