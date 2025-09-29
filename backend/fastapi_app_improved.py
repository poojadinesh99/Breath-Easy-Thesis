from fastapi import FastAPI, File, UploadFile, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import numpy as np
import uvicorn
import os
import joblib
import tempfile
import requests
import time
import logging
import json
from typing import Dict, Any

# === Import OpenSMILE helper ===
from utils.opensmile_utils import extract_features_for_inference
MODEL_PATH = os.path.join("ml", "models", "model_opensmile.pkl")
LABEL_MAP_PATH = os.path.join("ml", "models", "label_map.json")
model = joblib.load(MODEL_PATH)

with open(LABEL_MAP_PATH) as f:
    label_map = json.load(f)
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

# Optional HF fallback
HF_API_TOKEN = os.getenv("HF_TOKEN")
HF_MODEL_ENDPOINT = "https://api-inference.huggingface.co/models/PoojaDinesh99/breathe-easy-dualnet"

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

    # Load sklearn model
    if os.path.exists(MODEL_PATH):
        try:
            m = joblib.load(MODEL_PATH)
            model = m
            model_type = "sklearn"
            logger.info("✅ Loaded sklearn model from %s", MODEL_PATH)
        except Exception as e:
            logger.warning(f"⚠️ Failed to load sklearn model: {e}")

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
        inv_label_map = {}

_load_model_and_labels()

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
            suffix = os.path.splitext(file.filename or "")[1] or ".wav"
            fd, tmp_path = tempfile.mkstemp(suffix=suffix)
            os.close(fd)
            with open(tmp_path, "wb") as f:
                f.write(await file.read())
        elif audio_url:
            tmp_path = _download_to_tmp(audio_url)
        elif file_url:
            tmp_path = _download_to_tmp(file_url)
        else:
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

        # Extract OpenSMILE features to match training
        feats = extract_features_for_inference(
            tmp_path,
            feature_set=OS_FEATURE_SET,
            feature_level=OS_FEATURE_LEVEL,
            aggregate_if_lld=OS_AGG_IF_LLD,
        )

        # Try local model
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

        # Optional: HF fallback (simple passthrough)
        if HF_API_TOKEN:
            try:
                headers = {"Authorization": f"Bearer {HF_API_TOKEN}"}
                payload = {"inputs": feats.tolist()[0]}
                r = requests.post(HF_MODEL_ENDPOINT, headers=headers, json=payload, timeout=30)
                if r.status_code == 200:
                    hf = r.json()
                    return {
                        "predictions": hf.get("predictions", {}),
                        "label": hf.get("label"),
                        "confidence": hf.get("confidence"),
                        "source": "huggingface",
                        "processing_time": time.time() - t0,
                        "error": None,
                    }
                else:
                    raise RuntimeError(f"HF returned {r.status_code}: {r.text}")
            except Exception as e_hf:
                return {
                    "predictions": {},
                    "label": None,
                    "confidence": None,
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

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "local_model_available": model is not None,
        "model_type": model_type,
        "labels": inv_label_map,
        "hf_token_available": bool(HF_API_TOKEN),
    }

@app.get("/")
async def root():
    return {"message": "Breathe Easy API — use /predict/unified"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "8000")))

# === Import Whisper for speech-to-text ===
import whisper
from whisper import load_model

# -----------------------------------------------------------------------------
# Load Whisper model at startup
# -----------------------------------------------------------------------------
whisper_model = None
WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", "base")  # tiny, base, small, medium, large

def _load_whisper_model():
    global whisper_model
    try:
        logger.info(f"Loading Whisper model: {WHISPER_MODEL_SIZE}")
        whisper_model = load_model(WHISPER_MODEL_SIZE)
        logger.info("✅ Whisper model loaded successfully")
    except Exception as e:
        logger.error(f"❌ Failed to load Whisper model: {e}")
        whisper_model = None

_load_whisper_model()

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
            suffix = os.path.splitext(file.filename or "")[1] or ".wav"
            fd, tmp_path = tempfile.mkstemp(suffix=suffix)
            os.close(fd)
            with open(tmp_path, "wb") as f:
                f.write(await file.read())
        elif audio_url:
            tmp_path = _download_to_tmp(audio_url)
        elif file_url:
            tmp_path = _download_to_tmp(file_url)
        else:
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
