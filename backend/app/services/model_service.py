import os
import logging
import joblib
import json
import numpy as np
from typing import Dict, Any, Optional

from ..core.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ModelLoadError(Exception):
    """Custom exception for model loading failures."""
    pass

class ModelService:
    """Service to manage ML model loading and inference."""
    
    def __init__(self):
        self.model: Optional[Any] = None
        self.label_map: Dict[str, int] = {}
        self.inv_label_map: Dict[int, str] = {}
    
    def load_model(self) -> None:
        """Load the sklearn model and label map."""
        try:
            if not os.path.exists(settings.MODEL_PATH):
                raise ModelLoadError(f"Model file not found: {settings.MODEL_PATH}")
            
            if not os.path.exists(settings.LABEL_MAP_PATH):
                raise ModelLoadError(f"Label map not found: {settings.LABEL_MAP_PATH}")
            
            # Load model
            self.model = joblib.load(settings.MODEL_PATH)
            logger.info(f"✓ Loaded model from {settings.MODEL_PATH}")
            
            # Load label map
            with open(settings.LABEL_MAP_PATH, 'r') as f:
                self.label_map = json.load(f)
                self.inv_label_map = {v: k for k, v in self.label_map.items()}
            logger.info(f"✓ Loaded label map from {settings.LABEL_MAP_PATH}")
            
        except Exception as e:
            raise ModelLoadError(f"Failed to load model: {str(e)}")
    
    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Make predictions using the loaded model.
        
        Args:
            features: Dictionary of extracted features
            
        Returns:
            Dict containing predictions and confidence scores
        """
        if self.model is None:
            raise ModelLoadError("Model not loaded. Call load_model() first.")
        
        try:
            # Prepare feature vector
            feature_vector = self._prepare_features(features)
            
            # Get model predictions
            pred_proba = self.model.predict_proba([feature_vector])[0]
            pred_class = self.model.predict([feature_vector])[0]
            
            # Get confidence and class label
            confidence = float(np.max(pred_proba))
            predicted_class = self.inv_label_map.get(pred_class, "Unknown")
            
            # Prepare class probabilities
            class_probs = {
                self.inv_label_map.get(i, f"class_{i}"): float(p)
                for i, p in enumerate(pred_proba)
            }
            
            return {
                "predicted_class": predicted_class,
                "confidence": confidence,
                "class_probs": class_probs
            }
            
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            raise
    
    def _prepare_features(self, features: Dict[str, Any]) -> np.ndarray:
        """
        Prepare features for model input.
        
        Args:
            features: Dictionary of extracted features
            
        Returns:
            Numpy array of prepared features
        """
        # Use OpenSMILE features as base
        if "opensmile" not in features:
            raise ValueError("OpenSMILE features required for prediction")
            
        feature_vector = features["opensmile"]
        
        # Add basic audio features if available
        basic_features = [
            features.get("rms_energy", 0),
            features.get("zero_crossing_rate", 0),
            features.get("spectral_rolloff", 0),
            features.get("spectral_centroid", 0)
        ]
        
        return np.concatenate([feature_vector, basic_features])
