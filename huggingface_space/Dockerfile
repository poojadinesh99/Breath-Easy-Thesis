FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System dependencies for audio + model loading
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ffmpeg libsndfile1 && \
    rm -rf /var/lib/apt/lists/*

# Copy backend code and model files
COPY backend /app/backend

# Copy Hugging Face app code
COPY huggingface_space/main_app.py /app/main_app.py
COPY huggingface_space/requirements.txt /app/requirements.txt

# Install Python deps
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

EXPOSE 7860

CMD ["uvicorn", "main_app:app", "--host", "0.0.0.0", "--port", "7860"]
