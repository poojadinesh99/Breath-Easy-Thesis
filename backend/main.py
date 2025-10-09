
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

from app.api.endpoints import router as api_router
from app.services.model_service import model_service
from app.core.config import settings
from app.models.api_models import HealthResponse

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Thesis-Ready Application Structure ---
# This main.py file acts as the entry point to the application.
# By adopting a modular structure (api, services, models, core), the project
# becomes significantly cleaner, more maintainable, and easier to present in a
# thesis defense. It separates concerns, which is a fundamental principle of
# good software engineering.

app = FastAPI(
    title="Breathe Easy: AI-Powered Respiratory Analysis",
    description="A thesis-grade FastAPI backend for analyzing respiratory audio using machine learning. "
                "This API provides endpoints for disease classification and speech transcription.",
    version="2.0.0",
    # Adding contact and license info is good practice for a public-facing or academic project.
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

# --- CORS Middleware ---
# Cross-Origin Resource Sharing (CORS) is essential for allowing the frontend
# (likely a web or mobile app) to communicate with this backend. Using a wildcard
# is acceptable for development, but for production, it's better to restrict it
# to the specific domain of the frontend application.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, change to: ["https://your-frontend-domain.com"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- API Router Inclusion ---
# The main application includes the router from the `api` module. This keeps the
# main file clean and delegates all routing logic to the `endpoints.py` file.
app.include_router(api_router, prefix="/api/v1")

# --- Health Check Endpoint ---
# A /health endpoint is a standard practice for any deployed service. It allows
# automated systems (like Render's health checks) to verify that the application
# is running and properly configured. This is a crucial element for ensuring
# reliable deployment.
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

# --- Root Endpoint ---
# A simple root endpoint to confirm the API is up and provides basic info.
@app.get("/", tags=["System"])
async def root():
    """
    Root endpoint providing a welcome message.
    """
    return {"message": "Welcome to the Breathe Easy API. See /docs for details."}

# --- Application Startup Event ---
# The `on_event("startup")` decorator ensures that essential resources, like ML
# models, are loaded when the application starts, not on the first request.
# This is critical for performance, as it avoids a long delay for the first user.
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 Application starting up...")
    # The model_service is already initialized at import time, so this is just a log point.
    # If any other async setup is needed, it would go here.
    logger.info("✅ Application startup complete.")

if __name__ == "__main__":
    import uvicorn
    # This allows running the app directly for local development.
    # The host "0.0.0.0" makes it accessible from other devices on the same network.
    uvicorn.run(app, host="0.0.0.0", port=8000)
