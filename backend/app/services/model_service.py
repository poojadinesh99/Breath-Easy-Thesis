
import os
import logging
import joblib
import json
import whisper
import numpy as np
from typing import Dict, Any, Optional

from app.core.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ModelService:
    """
    A service class to manage the lifecycle and inference of machine learning models.
    
    This includes loading models (local or from Hugging Face), their corresponding
    label maps, and the Whisper model for transcriptions. This centralization follows
    best practices for building thesis-ready, modular applications.
    """
    def __init__(self):
        self.model: Optional[Any] = None
        self.model_type: Optional[str] = None
        self.inv_label_map: Dict[int, str] = {}
        self.whisper_model: Optional[Any] = None
        
        self._load_models()
        self._load_whisper()

    def _load_models(self):
        """
        Loads the primary classification model and its label map.
        
        It prioritizes Hugging Face if PREFER_HF is true, otherwise it loads a local
        scikit-learn model. This dual-capability is excellent for a thesis project,
        showcasing both local deployment and cloud-based inference.
        """
        if settings.PREFER_HF and settings.HF_API_TOKEN:
            logger.info("🤗 Using HuggingFace model as primary (PREFER_HF=true).")
            self.model_type = "huggingface"
            self.inv_label_map = {0: "abnormal", 1: "clear", 2: "wheezing", 3: "crackles"}
            logger.info("✅ HuggingFace model configured with default label map.")
            return

        model_path = os.path.join("/Users/themysticbrew/Documents/thesis_app/Breath-Easy-Thesis/backend", settings.MODEL_PATH)
        label_map_path = os.path.join("/Users/themysticbrew/Documents/thesis_app/Breath-Easy-Thesis/backend", settings.LABEL_MAP_PATH)

        if os.path.exists(model_path):
            try:
                self.model = joblib.load(model_path)
                self.model_type = "sklearn"
                logger.info(f"✅ Loaded local sklearn model from: {model_path}")
            except Exception as e:
                logger.error(f"🔥 Failed to load local model: {e}")
        
        if self.model is None and settings.HF_API_TOKEN:
            logger.info("📡 No local model found, using Hugging Face API as fallback.")
            self.model_type = "huggingface"
        elif self.model is None:
            logger.warning("⚠️ No model available (local or HuggingFace).")

        if os.path.exists(label_map_path):
            try:
                with open(label_map_path, "r") as f:
                    label_map = json.load(f)
                self.inv_label_map = {v: k for k, v in label_map.items()}
                logger.info(f"✅ Loaded label map: {self.inv_label_map}")
            except Exception as e:
                logger.error(f"🔥 Failed to load label map: {e}")
        else:
            if not self.inv_label_map:
                self.inv_label_map = {0: "abnormal", 1: "clear", 2: "wheezing", 3: "crackles"}
                logger.info("📋 Using fallback label map.")

    def _load_whisper(self):
        """
        Loads the Whisper model for audio transcription.
        
        Demonstrates the integration of a large language model (LLM) for a secondary,
        value-add task, which is a strong point in a modern AI thesis.
        """
        try:
            logger.info(f"Loading Whisper model: {settings.WHISPER_MODEL_SIZE}")
            self.whisper_model = whisper.load_model(settings.WHISPER_MODEL_SIZE)
            logger.info("✅ Whisper model loaded successfully.")
        except Exception as e:
            logger.error(f"🔥 Failed to load Whisper model: {e}")
            self.whisper_model = None

    def predict_local(self, features: np.ndarray) -> Dict[str, Any]:
        """
        Performs inference using the loaded local scikit-learn model.
        """
        if self.model is None or self.model_type != "sklearn":
            raise RuntimeError("Local sklearn model not loaded.")
        
        if hasattr(self.model, "predict_proba"):
            probabilities = self.model.predict_proba(features)[0]
            class_indices = list(self.model.classes_)
        else:
            prediction = self.model.predict(features)[0]
            class_indices = list(self.model.classes_) if hasattr(self.model, "classes_") else [prediction]
            probabilities = np.zeros(len(class_indices))
            probabilities[class_indices.index(prediction)] = 1.0

        labels = [self.inv_label_map.get(int(c), str(int(c))) for c in class_indices]
        predictions = {labels[i]: float(probabilities[i]) for i in range(len(labels))}
        top_index = int(np.argmax(probabilities))
        
        return {
            "predictions": predictions,
            "label": labels[top_index],
            "confidence": float(probabilities[top_index]),
            "source": "local",
        }

    def transcribe_audio(self, audio_path: str) -> str:
        """
        Transcribes audio using the loaded Whisper model.
        """
        if self.whisper_model is None:
            raise RuntimeError("Whisper model not loaded.")
        
        result = self.whisper_model.transcribe(audio_path)
        transcript = result["text"].strip()
        logger.info(f"🎤 Transcription result: '{transcript}'")
        return transcript

# Singleton instance to be used across the application
model_service = ModelService()
