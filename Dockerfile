# Base image
FROM python:3.10-slim

# Prevent Python from writing pyc files and force stdout flush
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# --- System dependencies (for audio etc.) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ffmpeg libsndfile1 && \
    rm -rf /var/lib/apt/lists/*

# --- Copy backend code and model files ---
COPY backend /app/backend

# --- Copy main app and requirements ---
COPY huggingface_space/main_app.py /app/main_app.py
COPY huggingface_space/requirements.txt /app/requirements.txt

# --- Install Python dependencies ---
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

# --- Expose port 7860 for Hugging Face ---
EXPOSE 7860

# --- Start FastAPI app ---
CMD ["uvicorn", "main_app:app", "--host", "0.0.0.0", "--port", "7860"]
