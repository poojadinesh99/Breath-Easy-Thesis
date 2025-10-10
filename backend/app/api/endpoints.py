from fastapi import APIRouter, File, UploadFile, Form, HTTPException, Depends
import time
import os
import logging
from starlette.responses import JSONResponse

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

@router.get("/health")
async def health_check():
    """
    Health check endpoint to verify the service is running.
    """
    return {"status": "ok", "message": "Breath Easy API is running"}

# Initialize Supabase Service
# This dependency injection pattern makes the app more testable and modular.
def get_supabase_service():
    return SupabaseService(url=settings.SUPABASE_URL, key=settings.SUPABASE_KEY)

async def validate_audio_file(file: UploadFile) -> bool:
    """Validate audio file size and format"""
    try:
        # Read first few bytes to verify it's a valid WAV file
        header = await file.read(44)  # WAV header is 44 bytes
        await file.seek(0)  # Reset file pointer
        
        if len(header) < 44:
            return False
            
        # Check WAV magic numbers
        if header[:4] != b'RIFF' or header[8:12] != b'WAVE':
            return False
            
        # Get file size
        file_size = 0
        while chunk := await file.read(8192):
            file_size += len(chunk)
        await file.seek(0)
        
        # Minimum 1 second of audio (44100 samples * 2 bytes per sample)
        if file_size < 88200:
            return False
            
        return True
    except Exception as e:
        logger.error(f"File validation error: {str(e)}")
        return False

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
    try:
        if not file and not audio_url:
            raise HTTPException(status_code=400, detail="No audio file or URL provided")

        if file:
            # Validate the audio file
            if not await validate_audio_file(file):
                return JSONResponse(
                    status_code=400,
                    content={
                        "error": "Invalid audio file",
                        "detail": "Audio file must be a valid WAV file with at least 1 second of audio"
                    }
                )
            
            # Save file temporarily
            temp_path = f"/tmp/audio_{int(time.time())}.wav"
            with open(temp_path, "wb") as buffer:
                content = await file.read()
                buffer.write(content)
                await file.seek(0)
            
            try:
                # Process the audio file
                predictions = await analysis_service.analyze_audio(temp_path)
                transcription = await analysis_service.transcribe_audio(temp_path)
                
                # Generate summary
                summary = generate_text_summary(predictions, transcription)
                
                # Log to Supabase
                try:
                    await supabase_service.log_analysis(predictions, summary)
                except Exception as e:
                    logger.error(f"Supabase logging error: {str(e)}")
                    # Continue even if logging fails
                
                return PredictionResponse(
                    predictions=predictions,
                    label=max(predictions.items(), key=lambda x: x[1])[0],
                    confidence=max(predictions.values()),
                    text_summary=summary
                )
            
            finally:
                # Clean up temp file
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                    
        else:  # audio_url provided
            # Process audio from URL
            predictions = await analysis_service.analyze_audio_url(audio_url)
            transcription = await analysis_service.transcribe_audio_url(audio_url)
            summary = generate_text_summary(predictions, transcription)
            
            try:
                await supabase_service.log_analysis(predictions, summary)
            except Exception as e:
                logger.error(f"Supabase logging error: {str(e)}")
            
            return PredictionResponse(
                predictions=predictions,
                label=max(predictions.items(), key=lambda x: x[1])[0],
                confidence=max(predictions.values()),
                text_summary=summary
            )
            
    except Exception as e:
        logger.error(f"Analysis error: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={
                "error": "Analysis failed",
                "detail": str(e)
            }
        )
