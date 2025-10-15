import sys, os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Add the backend directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

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
    try:
        # Test if we can import the backend
        from app.api.endpoints import router
        model_status = "loaded"
    except Exception as e:
        model_status = f"error: {str(e)}"
    
    return {
        "status": "ok",
        "models": model_status
    }

# Import and include the API router
try:
    from app.api.endpoints import router as api_router
    app.include_router(api_router, prefix="/api/v1")
    print("✓ API endpoints loaded successfully")
except ImportError as e:
    print(f"Warning: API endpoints not loaded: {e}")
    print("Only health checks available.")
