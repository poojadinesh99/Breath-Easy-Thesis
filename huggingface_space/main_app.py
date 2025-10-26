import sys, os
sys.path.append(os.getcwd())

from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse
import numpy as np
import joblib
import io
import json
import soundfile as sf

from backend.app.services.feature_extraction import extract_features as be_extract_features  # if exists
try:
    from backend.feature_extraction import extract_mfcc_features as local_extract
except Exception:
    local_extract = None


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
async def predict(file: UploadFile = File(...)):
    _lazy_load_model()
    raw = await file.read()
    data, sr = sf.read(io.BytesIO(raw))
    if data.ndim > 1:
        data = np.mean(data, axis=1)

    # Prefer project service extractor if available, else fallback to local MFCC
    if 'be_extract_features' in globals() and callable(be_extract_features):
        feats = be_extract_features(data, sr)
    elif local_extract is not None:
        feats = local_extract(data, sr)
    else:
        # Last-resort simple stats
        audio = data.astype(np.float32)
        feats = np.array([np.mean(audio), np.std(audio)], dtype=np.float32).reshape(1, -1)

    try:
        pred = MODEL.predict(feats)
        proba = getattr(MODEL, "predict_proba", None)
        conf = float(np.max(proba(feats))) if callable(proba) else None
        label_idx = pred[0] if len(pred) else None
        label_name = None
        if LABELS is not None and label_idx is not None:
            if isinstance(LABELS, dict):
                label_name = LABELS.get(str(label_idx), LABELS.get(label_idx))
            elif isinstance(LABELS, list) and isinstance(label_idx, (int, np.integer)) and label_idx < len(LABELS):
                label_name = LABELS[label_idx]
        return {"prediction": int(label_idx) if label_idx is not None else None, "label": label_name, "confidence": conf}
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

