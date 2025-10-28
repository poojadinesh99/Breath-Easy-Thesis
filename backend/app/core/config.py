"""
Core configuration module for the backend service.
Handles environment variables and paths.
"""
import os
from pathlib import Path
from typing import Optional
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Settings(BaseSettings):
    # Model settings
    MODEL_PATH: str = os.path.join(
        Path(__file__).parent.parent.parent,
        "ml/models/model_rf.pkl"
    )
    LABEL_MAP_PATH: str = os.path.join(
        Path(__file__).parent.parent.parent,
        "ml/models/label_map.json"
    )
    
    # Audio settings
    MIN_DURATION: float = 0.5  # minimum audio duration in seconds
    PREFER_HF: bool = False    # prefer local model over Hugging Face
    
    # Hugging Face settings
    HF_TOKEN: Optional[str] = None
    HF_SPACES_URL: Optional[str] = None
    USE_HF: bool = False
    USE_HF_FALLBACK: bool = False
    
    # Supabase settings
    SUPABASE_URL: Optional[str] = None
    SUPABASE_ANON_KEY: Optional[str] = None
    SUPABASE_KEY: Optional[str] = None  # Add this missing key
    SUPABASE_JWT_SECRET: Optional[str] = None
    
    # Feature extraction settings
    FEATURE_DIR: str = os.path.join(
        Path(__file__).parent.parent.parent,
        "data/features"
    )
    RAW_AUDIO_DIR: str = os.path.join(
        Path(__file__).parent.parent.parent,
        "data/raw"
    )
    
    class Config:
        env_file = os.path.join(Path(__file__).parent.parent.parent.parent, ".env")
        case_sensitive = True

settings = Settings()

# Ensure directories exist
os.makedirs(settings.FEATURE_DIR, exist_ok=True)
os.makedirs(settings.RAW_AUDIO_DIR, exist_ok=True)
