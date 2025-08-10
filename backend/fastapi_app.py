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
sys.path.append(os.path.dirname(__file__))  # Add current directory to sys.path
from extract_spectrogram import extract_features

app = FastAPI()

# Load trained model at startup with explicit relative path
model = joblib.load(os.path.join(os.path.dirname(__file__), "model.pkl"))

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


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

@app.get("/")
def read_root():
    return {"message": "✨ Welcome to the Breath-Easy API! ✨"}
