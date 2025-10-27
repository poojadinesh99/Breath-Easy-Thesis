---
<<<<<<< HEAD
title: Breath Easy – Respiratory Sound Analysis
emoji: 🫁
colorFrom: blue
colorTo: green
sdk: static
sdk_version: 1.0.0
app_file: index.html
pinned: false
---

# Breath Easy – Respiratory Sound Analysis

Upload or record a short breathing clip to detect potential respiratory symptoms using machine learning.

## Features

- **Audio Recording**: Record directly from your microphone
- **Real-time Analysis**: Instant prediction of respiratory patterns
- **ML-Powered**: Uses a trained Random Forest model to classify breathing sounds
- **User-Friendly**: Clean, intuitive interface with clear results

## How it works

1. Record or upload a short audio clip of breathing sounds
2. The system extracts MFCC (Mel-Frequency Cepstral Coefficients) features
3. A pre-trained Random Forest model analyzes the features
4. Results are displayed with clear, actionable feedback

## Model Details

- **Algorithm**: Random Forest Classifier
- **Features**: 120-dimensional MFCC features (mean + std of 20 coefficients)
- **Classes**: Normal, Cough, Heavy Breathing, Throat Clearing
- **Training Data**: Respiratory sound dataset

## Usage

Simply click the microphone button to record. The analysis will be performed automatically and results displayed instantly.
=======
title: Breath Easy – API Backend
emoji: 🫁
colorFrom: blue
colorTo: green
sdk: docker
sdk_version: 1.0.0
pinned: false
---

# Breath Easy – API Backend

FastAPI backend for respiratory sound analysis. Deploys via Docker on Hugging Face Spaces and exposes health (`/`) and inference (`/predict`) endpoints.

## Endpoints

- `GET /` — health/status
- `POST /predict` — multipart file upload (`file`) of audio (wav/flac) returns JSON with `prediction` and optional `confidence`.

## Deploy notes

- Space uses `sdk: docker` and starts `uvicorn main_app:app --port 7860`.
- `main_app.py` is the entrypoint in the image.
- Place `model_rf.pkl` next to the Dockerfile (already included).

## Model Notes

- Expects `model_rf.pkl` compatible with `joblib.load`.
- Replace placeholder feature function with your MFCC pipeline if needed.

## Usage

POST an audio file to `/predict` with form field `file`.

Example (curl):

curl -X POST -F "file=@sample.wav" https://hf.space/embed/<org>/<space-name>/predict
>>>>>>> ba1bff390b756777fd770507b38a05a91315caef
