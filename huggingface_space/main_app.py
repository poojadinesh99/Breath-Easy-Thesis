import sys, os
sys.path.append(os.getcwd())
from fastapi import FastAPI, UploadFile, File, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse
import numpy as np
import joblib
import io
import json
import soundfile as sf

try:
    from backend.app.services.feature_extraction import extract_features as be_extract_features
except ImportError as e:
    be_extract_features = None
    print("⚠️ Warning: Could not import full feature extractor:", e)

app = FastAPI(title="Breath Easy API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL = None
LABELS = None


def _lazy_load_model():
    """Lazy-load the trained RandomForest model + label map."""
    global MODEL, LABELS
    if MODEL is None:
        MODEL = joblib.load("backend/ml/models/model_rf.pkl")
    if LABELS is None:
        with open("backend/ml/models/label_map.json", "r") as f:
            LABELS = json.load(f)


@app.get("/")
def root():
    return {"status": "ok", "service": "breath-easy-backend"}


@app.post("/predict")
async def predict(request: Request, file: UploadFile | None = File(default=None)):
    """Run respiratory sound prediction."""
    _lazy_load_model()
    data = None
    sr = 16000

    # Prefer multipart file if provided
    if file is not None:
        raw = await file.read()
        data, sr = sf.read(io.BytesIO(raw))
    else:
        # Fallback: accept JSON body with {"audio_data": [..], "sample_rate": 16000}
        try:
            payload = await request.json()
            samples = payload.get("audio_data")
            if samples is None:
                return JSONResponse({"error": "Missing audio_data"}, status_code=400)
            sr = int(payload.get("sample_rate", 16000))
            data = np.asarray(samples, dtype=np.float32)
        except Exception as e:
            return JSONResponse({"error": f"Invalid request body: {e}"}, status_code=400)
    if data.ndim > 1:
        data = np.mean(data, axis=1)

    # ✅ Use project extractor if available. It should accept (waveform, sr).
    if callable(be_extract_features):
        feature_out = be_extract_features(data, sr)
        feats = feature_out.get("model_features") if isinstance(feature_out, dict) else feature_out
    else:
        # Simple fallback (just mean/std)
        audio = data.astype(np.float32)
        feats = np.array([np.mean(audio), np.std(audio)], dtype=np.float32).reshape(1, -1)

    try:
        pred = MODEL.predict([feats[0]]) if feats.ndim > 1 else MODEL.predict(feats)
        proba_fn = getattr(MODEL, "predict_proba", None)
        conf = float(np.max(proba_fn(feats))) if callable(proba_fn) else None

        label_idx = int(pred[0]) if len(pred) else None
        label_name = None
        if LABELS is not None and label_idx is not None:
            if isinstance(LABELS, dict):
                label_name = LABELS.get(str(label_idx), LABELS.get(label_idx))
            elif isinstance(LABELS, list) and label_idx < len(LABELS):
                label_name = LABELS[label_idx]

        return {
            "prediction": label_idx,
            "label": label_name,
            "confidence": conf,
        }
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)
