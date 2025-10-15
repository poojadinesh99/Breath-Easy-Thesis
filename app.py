import sys, os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Create a new FastAPI app
app = FastAPI(title="Breath Analysis API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health endpoints for Hugging Face
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "status": "ok",
        "message": "Breathe Easy API Root Active"
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "ok",
        "models": "loaded"
    }

# Import and include the API router
try:
    from backend.app.api.endpoints import router as api_router
    app.include_router(api_router, prefix="/api/v1")
except ImportError:
    print("Warning: API endpoints not loaded. Only health checks available.")
