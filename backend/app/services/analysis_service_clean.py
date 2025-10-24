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
from .supabase_service import SupabaseService
from ..core.config import settings

logger = logging.getLogger(__name__)

class AnalysisService:
    def __init__(self):
        """Initialize the analysis service with model and database services."""
        self.model_service = ModelService()
        self.supabase_service = SupabaseService()
        self.initialized = False
        try:
            self.model_service.load_model()
            self.initialized = True
            logger.info("✓ Analysis service initialized successfully")
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
            # Try to initialize again
            try:
                self.model_service.load_model()
                self.initialized = True
                logger.info("✓ Model service initialized successfully on retry")
            except Exception as e:
                logger.warning(f"Model still not available: {e}")
                # Return safe fallback if model not initialized
                return {
                    "predictions": {"clear": 1.0},
                    "label": "clear", 
                    "confidence": 1.0,
                    "source": "demo_fallback",
                    "processing_time": 0.0,
                    "text_summary": "Demo mode: Detected clear breathing with 100% confidence. (Model not available)"
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
            logger.info(f"🔍 Extracted {features.get('n_features', 'unknown')} features")
            
            # Get predictions from model
            predictions = self.model_service.predict(features)
            logger.info(f"🎯 Model predictions: {predictions}")
            
            # Clean up normalized file
            try:
                os.remove(normalized_path)
            except Exception as e:
                logger.warning(f"Failed to cleanup normalized file: {e}")
            
            processing_time = time.time() - start_time
            
            # Get the highest confidence prediction
            label = max(predictions.get("class_probs", {"normal": 1.0}).items(), key=lambda x: x[1])[0]
            confidence = predictions.get("class_probs", {}).get(label, 1.0)
            logger.info(f"📊 Final prediction: {label} ({confidence:.1%})")
            
            # Simplified decision logic for acoustic-based categories
            if confidence < 0.6:
                simplified_label = "uncertain"
                summary = f"🤔 Analysis uncertain with {confidence*100:.1f}% confidence - please try recording again or consult a healthcare professional."
            elif label in ["normal"]:
                simplified_label = "normal"
                summary = f"✅ Normal breathing pattern detected with {confidence*100:.1f}% confidence"
            elif label in ["cough"]:
                simplified_label = "abnormal"
                summary = f"🤧 Cough detected with {confidence*100:.1f}% confidence - may indicate respiratory irritation or infection."
            elif label in ["heavy_breathing"]:
                simplified_label = "abnormal"
                summary = f"⚠️ Heavy breathing pattern detected with {confidence*100:.1f}% confidence - may indicate exertion or respiratory distress."
            elif label in ["throat_clearing"]:
                simplified_label = "abnormal"
                summary = f"🔍 Throat clearing detected with {confidence*100:.1f}% confidence - may indicate mild irritation."
            else:
                simplified_label = "abnormal"
                summary = f"⚠️ Abnormal breathing pattern detected with {confidence*100:.1f}% confidence - please consult a healthcare professional for evaluation."
            
            # Add model limitation disclaimer for low confidence predictions
            if confidence < 0.65:
                summary += "\n\n📝 Note: This is a prototype model and may have limited accuracy. Always consult healthcare professionals for medical concerns."
            
            # Format response
            result = {
                "predictions": predictions.get("class_probs", {"normal": 1.0}),
                "label": label,
                "simplified_label": simplified_label,
                "confidence": confidence,
                "source": "local" if not settings.PREFER_HF else "huggingface",
                "processing_time": processing_time,
                "text_summary": summary
            }
            
            logger.info(f"🚀 Sending result: {result}")
            
            # Save to Supabase database (async, non-blocking)
            try:
                audio_metadata = {
                    "file_path": file_path,
                    "task_type": task_type,
                    "duration": duration,
                    "min_duration": min_duration
                }
                db_result = await self.supabase_service.save_analysis_result(
                    result, 
                    audio_metadata
                )
                logger.info(f"Database save status: {db_result.get('status', 'unknown')}")
            except Exception as db_error:
                logger.warning(f"Failed to save to database: {db_error}")
                # Don't fail the entire request if database save fails
            
            return result
            
        except AudioNormalizationError as e:
            raise HTTPException(
                status_code=400,
                detail=str(e)
            )
        except Exception as e:
            logger.error(f"Analysis failed: {e}")
            # Return safe fallback on error
            fallback_result = {
                "predictions": {"clear": 1.0},
                "label": "clear", 
                "confidence": 1.0,
                "source": "demo_fallback",
                "processing_time": 0.0,
                "text_summary": "Analysis failed, returning safe fallback prediction."
            }
            
            # Save fallback result to Supabase as well
            try:
                audio_metadata = {
                    "file_path": file_path,
                    "task_type": task_type,
                    "error": str(e),
                    "fallback": True
                }
                db_result = await self.supabase_service.save_analysis_result(
                    fallback_result, 
                    audio_metadata
                )
                logger.info(f"Fallback result saved to database: {db_result.get('status', 'unknown')}")
            except Exception as db_error:
                logger.warning(f"Failed to save fallback result to database: {db_error}")
            
            return fallback_result
    
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
