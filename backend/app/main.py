"""
Main FastAPI application for the breath and speech analysis backend.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.endpoints import router as api_router

app = FastAPI(
    title="Breath-Easy Analysis API",
    description="API for analyzing breath and speech patterns for respiratory health assessment",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Include API routes
app.include_router(api_router, prefix="/api/v1")
