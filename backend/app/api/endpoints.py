"""
API routes for the unified analysis endpoint.
Handles both breath and speech analysis with proper error handling.
"""
import os
import tempfile
from typing import Optional
from fastapi import APIRouter, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse

from ..services.analysis_service import AnalysisService
from ..core.config import settings

router = APIRouter()
analysis_service = AnalysisService()

@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "api_version": "1.0.0"
    }

@router.post("/unified")
async def analyze_audio(
    file: UploadFile,
    task_type: str = Form(...),
    min_duration: Optional[float] = Form(0.5)
):
    """
    Unified endpoint for analyzing breath and speech recordings.
    
    Args:
        file: Audio file (WAV format)
        task_type: Type of analysis ("breath" or "speech")
        min_duration: Minimum required duration in seconds
        
    Returns:
        JSON response with analysis results
    """
    if not file.filename.lower().endswith('.wav'):
        raise HTTPException(
            status_code=400,
            detail="Only WAV files are supported"
        )
    
    if task_type not in ["breath", "speech"]:
        raise HTTPException(
            status_code=400,
            detail='task_type must be either "breath" or "speech"'
        )
    
    try:
        # Save uploaded file
        temp_dir = tempfile.mkdtemp()
        temp_path = os.path.join(temp_dir, "input.wav")
        
        with open(temp_path, "wb") as f:
            contents = await file.read()
            f.write(contents)
        
        # Analyze audio
        result = await analysis_service.analyze_audio(
            temp_path,
            task_type,
            min_duration
        )
        
        # Clean up
        os.remove(temp_path)
        os.rmdir(temp_dir)
        
        return JSONResponse(
            content={
                "status": "success",
                "data": result
            }
        )
        
    except Exception as e:
        # Clean up on error
        if os.path.exists(temp_path):
            os.remove(temp_path)
        if os.path.exists(temp_dir):
            os.rmdir(temp_dir)
            
        if isinstance(e, HTTPException):
            raise e
        
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )
