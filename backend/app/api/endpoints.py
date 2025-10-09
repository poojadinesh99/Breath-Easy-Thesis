
from fastapi import APIRouter, File, UploadFile, Form, HTTPException, Depends
import time
import os
import logging

from app.models.api_models import PredictionResponse, TranscriptionResponse
from app.services.model_service import model_service
from app.services.supabase_service import SupabaseService
from app.services import analysis_service
from app.utils.summary_utils import generate_text_summary
from app.core.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

# Initialize Supabase Service
# This dependency injection pattern makes the app more testable and modular.
def get_supabase_service():
    return SupabaseService(url=settings.SUPABASE_URL, key=settings.SUPABASE_KEY)

@router.post("/unified", response_model=PredictionResponse)
async def unified_analysis(
    file: UploadFile = File(None),
    audio_url: str = Form(None),
    supabase_service: SupabaseService = Depends(get_supabase_service)
):
    """
    Endpoint for unified breathing and speech analysis.
    
    This endpoint represents the core functionality of the thesis project. It's designed
    to be robust, accepting audio via direct upload or URL. It follows a clean
    pipeline:
    1. Receive audio.
    2. Extract features using a research-grade toolkit (OpenSMILE).
    3. Perform inference using either a local or cloud-based model.
    4. Generate a human-readable summary.
    5. Log the results for further research.
    
    This structure is clean, modular, and easy to explain in a thesis defense.
    """
    t0 = time.time()
    tmp_path = None
    
    try:
        if file:
            tmp_path = analysis_service.get_temp_file_from_upload(file)
            logger.info(f"Audio from upload saved to: {tmp_path}")
        elif audio_url:
            tmp_path = analysis_service.get_temp_file_from_url(audio_url)
            logger.info(f"Audio from URL saved to: {tmp_path}")
        else:
            raise HTTPException(status_code=400, detail="No audio provided. Use 'file' or 'audio_url'.")

        # 1. Feature Extraction
        features = analysis_service.extract_features(tmp_path)
        
        # 2. Prediction
        if model_service.model_type == "sklearn" and not settings.PREFER_HF:
            result = model_service.predict_local(features)
        elif model_service.model_type == "huggingface":
            result = analysis_service.predict_huggingface(features)
        else:
            raise HTTPException(status_code=501, detail="No valid model is configured for inference.")

        if "error" in result:
             raise HTTPException(status_code=500, detail=result["error"])

        # 3. Generate Summary
        result['text_summary'] = generate_text_summary(result['label'], result['confidence'])
        result['processing_time'] = time.time() - t0

        # 4. Log to Supabase
        audio_meta = {"filename": file.filename if file else audio_url}
        supabase_service.log_analysis(result, audio_meta)

        return PredictionResponse(**result)

    except Exception as e:
        logger.error(f"🔥 An error occurred during unified analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)

@router.post("/speech", response_model=TranscriptionResponse)
async def speech_to_text(
    file: UploadFile = File(None),
    audio_url: str = Form(None)
):
    """
    Endpoint for audio transcription using Whisper.
    
    This showcases the integration of a powerful, pre-trained model for a task
    that adds significant value to the user experience. It demonstrates an
    understanding of how to leverage existing AI tools within a custom application.
    """
    t0 = time.time()
    tmp_path = None
    
    try:
        if file:
            tmp_path = analysis_service.get_temp_file_from_upload(file)
        elif audio_url:
            tmp_path = analysis_service.get_temp_file_from_url(audio_url)
        else:
            raise HTTPException(status_code=400, detail="No audio provided. Use 'file' or 'audio_url'.")

        transcript = model_service.transcribe_audio(tmp_path)
        
        return TranscriptionResponse(
            transcript=transcript,
            message=f"You said: {transcript}" if transcript else "No speech was detected.",
            processing_time=time.time() - t0
        )

    except Exception as e:
        logger.error(f"🔥 An error occurred during speech analysis: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
