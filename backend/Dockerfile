# Use Python 3.10 slim image as base
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies (audio libs, compilers) in one go, clean cache to keep image small
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy only requirements first for better Docker caching
COPY requirements.txt .

# Install Python dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Remove explicit PyTorch install here if it's already in requirements.txt
# If not, better to add torch packages to requirements.txt instead of separate RUN
# But if needed, keep this here:
RUN pip install --no-cache-dir torch torchvision torchaudio python-dotenv

# Copy backend code AFTER dependencies installed for caching benefits
COPY . .

# Set environment variables (PYTHONPATH for imports)
ENV PYTHONPATH=/app

# Expose FastAPI port
EXPOSE 8000

# Use your actual FastAPI app file and app instance
CMD ["uvicorn", "fastapi_app_improved:app", "--host", "0.0.0.0", "--port", "8000"]
