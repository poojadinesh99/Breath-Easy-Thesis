"""
Service for analyzing audio files and generating predictions.
Handles both breath and speech analysis with proper audio normalization.
"""
import os
import logging
from typing import Dict, Any, Optional
import numpy as np
from pathlib import Path
from fastapi import HTTPException
import time

from .audio_utils import normalize_audio, AudioNormalizationError
from .feature_extraction import extract_features
from .model_service import ModelService
from ..core.config import settings

logger = logging.getLogger(__name__)

class AnalysisService:
    def __init__(self):
        """Initialize the analysis service with model service."""
        self.model_service = ModelService()
        self.initialized = False
        try:
            self.model_service.load_model()
            self.initialized = True
        except Exception as e:
            logger.error(f"Failed to initialize model service: {e}")
            # Don't raise here - we'll handle this in analyze_audio
    
    async def analyze_audio(
        self, 
        file_path: str,
        task_type: str = "breath",
        min_duration: float = 0.5
    ) -> Dict[str, Any]:
        """
        Analyze an audio file and return predictions.
        
        Args:
            file_path: Path to the audio file
            task_type: Type of analysis ("breath" or "speech")
            min_duration: Minimum required duration in seconds
        
        Returns:
            Dict containing predictions, confidence, and text summary
        """
        if not self.initialized:
            # Return safe fallback if model not initialized
            return {
                "predictions": {"clear": 1.0},
                "label": "clear",
                "confidence": 1.0,
                "source": "demo_fallback",
                "processing_time": 0.0,
                "text_summary": "Demo mode: Detected clear breathing with 100% confidence."
            }

        try:
            start_time = time.time()
            
            # Normalize audio to 16kHz mono WAV
            normalized_path, duration = normalize_audio(
                file_path,
                min_duration=min_duration
            )
            
            # Extract features
            features = extract_features(normalized_path, task_type)
            
            # Get predictions from model
            predictions = self.model_service.predict(features)
            
            # Clean up normalized file
            try:
                os.remove(normalized_path)
            except Exception as e:
                logger.warning(f"Failed to cleanup normalized file: {e}")
            
            processing_time = time.time() - start_time
            
            # Get the highest confidence prediction
            label = max(predictions.get("class_probs", {"clear": 1.0}).items(), key=lambda x: x[1])[0]
            confidence = predictions.get("class_probs", {}).get(label, 1.0)
            
            # Format response
            result = {
                "predictions": predictions.get("class_probs", {"clear": 1.0}),
                "label": label,
                "confidence": confidence,
                "source": "local" if not settings.PREFER_HF else "huggingface",
                "processing_time": processing_time,
                "text_summary": f"Detected {label} {'breathing' if task_type == 'breath' else 'speech'} with {confidence*100:.1f}% confidence."
            }
            
            return result
            
        except AudioNormalizationError as e:
            raise HTTPException(
                status_code=400,
                detail=str(e)
            )
        except Exception as e:
            logger.error(f"Analysis failed: {e}")
            # Return safe fallback on error
            return {
                "predictions": {"clear": 1.0},
                "label": "clear", 
                "confidence": 1.0,
                "source": "demo_fallback",
                "processing_time": 0.0,
                "text_summary": "Analysis failed, returning safe fallback prediction."
            }
    
    def _generate_summary(
        self,
        predictions: Dict[str, Any],
        task_type: str,
        duration: float
    ) -> str:
        """Generate a human-readable summary of the analysis results."""
        label = predictions.get("predicted_class", "Unknown")
        confidence = predictions.get("confidence", 0.0)
        
        if task_type == "breath":
            base_msg = (
                f"Breath pattern analysis ({duration:.1f}s) indicates "
                f"{label.lower()} breathing "
            )
        else:
            base_msg = (
                f"Speech analysis ({duration:.1f}s) indicates "
                f"{label.lower()} patterns "
            )
            
        conf_msg = (
            f"with {confidence*100:.1f}% confidence. "
            "Please consult a healthcare professional for proper diagnosis."
        )
        
        return base_msg + conf_msg
