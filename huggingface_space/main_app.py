import sys, os
sys.path.append(os.getcwd())
sys.path.append(os.path.join(os.getcwd(), '..'))

from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse
import numpy as np
import joblib
import io
import json
import soundfile as sf

try:
    from backend.app.services.feature_extraction import extract_features as be_extract_features
except ImportError:
    be_extract_features = None
    print("⚠️ Warning: Could not import full feature extractor")

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
        MODEL = joblib.load("model_rf.pkl")
    if LABELS is None:
        with open("label_map.json", "r") as f:
            LABELS = json.load(f)


@app.get("/")
def root():
    return {"status": "ok", "service": "breath-easy-backend"}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    """Run respiratory sound prediction."""
    _lazy_load_model()
    raw = await file.read()
    data, sr = sf.read(io.BytesIO(raw))
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
        # Ensure feats is 2D for sklearn
        if feats.ndim == 1:
            feats = feats.reshape(1, -1)

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
