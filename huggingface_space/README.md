---
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
