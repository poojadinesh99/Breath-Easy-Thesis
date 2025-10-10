import sys
import os
from pathlib import Path

# Get the absolute path to the backend directory
BACKEND_DIR = Path(__file__).resolve().parent
APP_DIR = BACKEND_DIR / 'app'

# Add paths to Python path
sys.path.extend([str(BACKEND_DIR), str(APP_DIR)])

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

# Local imports
from app.core.config import settings
from app.models.api_models import HealthResponse
from app.services.model_service import model_service
from app.api.endpoints import router as api_router

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Breathe Easy: AI-Powered Respiratory Analysis",
    description="A thesis-grade FastAPI backend for analyzing respiratory audio using machine learning. "
                "This API provides endpoints for disease classification and speech transcription.",
    version="2.0.0",
    contact={
        "name": "Thesis Project - AI for Healthcare",
        "url": "http://example.com/project-page",
        "email": "project-contact@example.com",
    },
    license_info={
        "name": "MIT License",
        "url": "https://opensource.org/licenses/MIT",
    },
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development - update for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router, prefix="/api/v1")

@app.get("/health", response_model=HealthResponse, tags=["System"])
def health_check():
    """
    Provides a health check of the service, including model availability.
    """
    return HealthResponse(
        status="healthy",
        local_model_available=model_service.model is not None,
        model_type=model_service.model_type,
        labels=model_service.inv_label_map,
        hf_token_available=bool(settings.HF_API_TOKEN),
        whisper_model_available=model_service.whisper_model is not None,
        whisper_model_size=settings.WHISPER_MODEL_SIZE,
    )

@app.get("/", tags=["System"])
async def root():
    """
    Root endpoint providing a welcome message.
    """
    return {"message": "Welcome to the Breathe Easy API. See /docs for details."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
