
import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    """
    Configuration settings for the application.
    
    Settings are loaded from environment variables.
    """
    # Supabase configuration
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")

    # Model configuration
    MODEL_PATH: str = os.getenv("MODEL_PATH", "ml/models/model_opensmile.pkl")
    LABEL_MAP_PATH: str = os.getenv("LABEL_MAP_PATH", "ml/models/label_map.json")
    
    # Hugging Face configuration
    HF_API_TOKEN: str = os.getenv("HF_TOKEN", "")
    USE_HF: bool = os.getenv("USE_HF", "true").lower() == "true"
    HF_MODEL_ENDPOINT: str = "https://api-inference.huggingface.co/models/PoojaDinesh99/breathe-easy-dualnet"
    PREFER_HF: bool = os.getenv("PREFER_HF", "false").lower() == "true"

    # Whisper configuration
    WHISPER_MODEL_SIZE: str = os.getenv("WHISPER_MODEL_SIZE", "base")

    class Config:
        case_sensitive = True

settings = Settings()
