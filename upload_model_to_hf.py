#!/usr/bin/env python3
"""
Upload model and backend files to Hugging Face Hub.
This script uploads the large model.pkl file first, then the rest of the backend folder.
"""

import os
from pathlib import Path
from dotenv import load_dotenv
from huggingface_hub import HfApi
import logging
import tempfile
import shutil

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()
HF_TOKEN = os.getenv("HF_TOKEN")

if not HF_TOKEN:
    raise ValueError("HF_TOKEN not found in .env file. Please add it to your .env file.")

# Configuration
REPO_ID = "PoojaDinesh99/breathe-easy-dualnet"
REPO_TYPE = "model"
BACKEND_PATH = Path("backend")
MODEL_FILE = BACKEND_PATH / "model.pkl"

def main():
    """Main function to upload model and backend files to Hugging Face Hub."""
    
    # Initialize Hugging Face API
    api = HfApi(token=HF_TOKEN)
    
    # Step 1: Verify model file exists
    if not MODEL_FILE.exists():
        raise FileNotFoundError(f"Model file not found: {MODEL_FILE}")
    
    logger.info(f"Found model file: {MODEL_FILE} ({MODEL_FILE.stat().st_size / (1024*1024):.2f} MB)")
    
    # Step 2: Upload the large model file first
    logger.info("Step 1: Uploading large model.pkl file...")
    try:
        api.upload_file(
            path_or_fileobj=str(MODEL_FILE),
            path_in_repo="model.pkl",
            repo_id=REPO_ID,
            repo_type=REPO_TYPE,
            token=HF_TOKEN
        )
        logger.info("Successfully uploaded model.pkl")
    except Exception as e:
        logger.error(f"Failed to upload model.pkl: {e}")
        raise
    
    # Step 3: Upload the rest of the backend folder without model.pkl
    logger.info("Step 2: Uploading remaining backend files...")
    
    # Create temporary directory excluding model.pkl
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_backend = Path(temp_dir) / "backend"
        
        # Copy all files except model.pkl
        shutil.copytree(BACKEND_PATH, temp_backend)
        
        # Remove model.pkl from temp directory
        temp_model_file = temp_backend / "model.pkl"
        if temp_model_file.exists():
            temp_model_file.unlink()
        
        # Upload the remaining files
        try:
            api.upload_large_folder(
                folder_path=str(temp_backend),
                repo_id=REPO_ID,
                repo_type=REPO_TYPE,
            )
            logger.info("Successfully uploaded remaining backend files")
        except Exception as e:
            logger.error(f" Failed to upload remaining backend files: {e}")
            raise
    
    logger.info("All files uploaded successfully to Hugging Face Hub!")

if __name__ == "__main__":
    main()
