from fastapi import FastAPI, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import shutil
import numpy as np
import uvicorn
import os
import joblib
import tempfile
import requests
import sys
import time
import logging
from typing import Optional
from dotenv import load_dotenv

sys.path.append(os.path.dirname(__file__))  # Add current directory to sys.path
from backend.archive_librosa.extract_spectrogram import extract_features

load_dotenv()
app = FastAPI()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load trained model at startup with explicit relative path
try:
    model = joblib.load(os.path.join(os.path.dirname(__file__), "model.pkl"))
    logger.info("✅ Local PyTorch model loaded successfully")
except Exception as e:
    logger.warning(f"⚠️ Could not load local model: {e}")
    model = None

# Hugging Face configuration
HF_API_TOKEN = os.getenv("HF_TOKEN")
HF_MODEL_ENDPOINT = "https://api-inference.huggingface.co/models/PoojaDinesh99/breathe-easy-dualnet"

# Allow all origins for CORS (adjust as needed)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/predict")
async def predict(file: UploadFile = File(None), audio_url: str = Form(None)):
    """
    Predict endpoint accepts either an uploaded WAV file or a public audio URL.
    Extracts features and returns model prediction.
    """
    if file is None and audio_url is None:
        return JSONResponse(content={"error": "No audio file or URL provided"}, status_code=400)

    tmp_file_path = None

    try:
        if file is not None:
            # Save uploaded file to a temporary file
            suffix = os.path.splitext(file.filename)[1] if file.filename else ".wav"
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                tmp_file_path = tmp.name
                shutil.copyfileobj(file.file, tmp)
        else:
            # Download audio from URL and save to temporary file
            response = requests.get(audio_url, stream=True)
            if response.status_code != 200:
                return JSONResponse(content={"error": f"Failed to download audio from URL: {audio_url}"}, status_code=400)
            with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
                tmp_file_path = tmp.name
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        tmp.write(chunk)

        # Extract features using the implemented function
        features = extract_features(tmp_file_path)

        # Predict using the loaded model
        prediction = model.predict(features)
        prediction_proba = model.predict_proba(features) if hasattr(model, "predict_proba") else None

        # Prepare response
        response = {
            "prediction": prediction[0] if prediction is not None else None,
        }
        if prediction_proba is not None:
            response["prediction_proba"] = prediction_proba[0].tolist()

        return JSONResponse(content=response)

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

    finally:
        # Clean up temporary file
        if tmp_file_path and os.path.exists(tmp_file_path):
            os.remove(tmp_file_path)


@app.post("/predict/unified")
async def predict_unified(
    file: UploadFile = File(None), 
    audio_url: str = Form(None),
    use_hf_fallback: bool = Form(True)
):
    """
    Unified prediction endpoint that tries local PyTorch model first,
    falls back to Hugging Face Inference API on failure, and returns
    a unified JSON response with prediction and source.
    
    Parameters:
    - file: UploadFile - Audio file to analyze
    - audio_url: str - Public URL to audio file
    - use_hf_fallback: bool - Whether to use HF fallback (default: True)
    
    Returns:
    {
        "prediction": str,
        "confidence": float,
        "source": "local" | "huggingface",
        "model_type": "pytorch" | "sklearn",
        "processing_time": float,
        "success": bool,
        "error": str (if any)
    }
    """
    start_time = time.time()
    
    if file is None and audio_url is None:
        return JSONResponse(
            content={
                "success": False,
                "error": "No audio file or URL provided",
                "source": None,
                "prediction": None,
                "processing_time": 0
            },
            status_code=400
        )

    tmp_file_path = None
    
    try:
        # Handle file/URL input
        if file is not None:
            suffix = os.path.splitext(file.filename)[1] if file.filename else ".wav"
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                tmp_file_path = tmp.name
                shutil.copyfileobj(file.file, tmp)
        else:
            response = requests.get(audio_url, stream=True)
            if response.status_code != 200:
                return JSONResponse(
                    content={
                        "success": False,
                        "error": f"Failed to download audio from URL: {audio_url}",
                        "source": None,
                        "prediction": None,
                        "processing_time": 0
                    },
                    status_code=400
                )
            with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
                tmp_file_path = tmp.name
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        tmp.write(chunk)

        # Extract features
        features = extract_features(tmp_file_path)
        
        # Try local model first
        if model is not None:
            try:
                prediction = model.predict(features)[0]
                confidence = None
                if hasattr(model, "predict_proba"):
                    proba = model.predict_proba(features)[0]
                    confidence = float(max(proba))
                
                processing_time = time.time() - start_time
                return JSONResponse(content={
                    "success": True,
                    "prediction": str(prediction),
                    "confidence": confidence,
                    "source": "local",
                    "model_type": "sklearn",
                    "processing_time": processing_time,
                    "error": None
                })
            except Exception as e:
                logger.warning(f"Local model failed: {e}")
                if not use_hf_fallback:
                    processing_time = time.time() - start_time
                    return JSONResponse(
                        content={
                            "success": False,
                            "error": str(e),
                            "source": "local",
                            "prediction": None,
                            "processing_time": processing_time
                        },
                        status_code=500
                    )
        
        # Fallback to Hugging Face Inference API
        if use_hf_fallback and HF_API_TOKEN:
            try:
                headers = {"Authorization": f"Bearer {HF_API_TOKEN}"}
                
                # Convert features to format expected by HF API
                payload = {
                    "inputs": features.tolist() if hasattr(features, 'tolist') else features
                }
                
                response = requests.post(
                    HF_MODEL_ENDPOINT,
                    headers=headers,
                    json=payload,
                    timeout=30
                )
                
                if response.status_code == 200:
                    hf_result = response.json()
                    processing_time = time.time() - start_time
                    
                    return JSONResponse(content={
                        "success": True,
                        "prediction": str(hf_result[0] if isinstance(hf_result, list) else hf_result),
                        "confidence": None,
                        "source": "huggingface",
                        "model_type": "pytorch",
                        "processing_time": processing_time,
                        "error": None
                    })
                else:
                    raise Exception(f"HF API returned {response.status_code}: {response.text}")
                    
            except Exception as e:
                processing_time = time.time() - start_time
                return JSONResponse(
                    content={
                        "success": False,
                        "error": str(e),
                        "source": "huggingface",
                        "prediction": None,
                        "processing_time": processing_time
                    },
                    status_code=500
                )
        
        # No fallback available
        processing_time = time.time() - start_time
        return JSONResponse(
            content={
                "success": False,
                "error": "No model available for prediction",
                "source": None,
                "prediction": None,
                "processing_time": processing_time
            },
            status_code=503
        )

    except Exception as e:
        processing_time = time.time() - start_time
        return JSONResponse(
            content={
                "success": False,
                "error": str(e),
                "source": None,
                "prediction": None,
                "processing_time": processing_time
            },
            status_code=500
        )

    finally:
        # Clean up temporary file
        if tmp_file_path and os.path.exists(tmp_file_path):
            os.remove(tmp_file_path)


@app.get("/health")
def health_check():
    """Health check endpoint to verify service status"""
    return {
        "status": "healthy",
        "local_model_available": model is not None,
        "hf_token_available": HF_API_TOKEN is not None,
        "endpoints": ["/predict", "/predict/unified"]
    }


@app.get("/")
async def root():
    return {"message": "Welcome to Breathe Easy API. Use /predict/unified for inference."}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
