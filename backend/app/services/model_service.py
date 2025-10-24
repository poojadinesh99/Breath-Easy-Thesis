import os
import logging
import joblib
import json
import numpy as np
from typing import Dict, Any, Optional
import warnings
from ..core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ModelLoadError(Exception):
    pass


class ModelService:
    """Service to manage ML model loading and inference."""

    def __init__(self):
        self.model: Optional[Any] = None
        self.inv_label_map: Dict[int, str] = {}

    # -------------------------------------------------------
    def load_model(self) -> None:
        """Load trained sklearn model and label map."""
        try:
            if not os.path.exists(settings.MODEL_PATH):
                raise ModelLoadError(f"Model file not found: {settings.MODEL_PATH}")
            if not os.path.exists(settings.LABEL_MAP_PATH):
                raise ModelLoadError(f"Label map not found: {settings.LABEL_MAP_PATH}")

            with warnings.catch_warnings():
                warnings.filterwarnings("ignore", category=UserWarning, module="sklearn")
                self.model = joblib.load(settings.MODEL_PATH)
            logger.info(f"✓ Loaded model from {settings.MODEL_PATH}")

            # readable names from JSON, numeric order from model
            with open(settings.LABEL_MAP_PATH, "r") as f:
                label_map = json.load(f)
            self.inv_label_map = {int(k): v for k, v in label_map.items()}
            logger.info(f"✓ Using readable label map: {self.inv_label_map}")

        except Exception as e:
            raise ModelLoadError(f"Failed to load model: {e}")

    # -------------------------------------------------------
    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Predict with adaptive normalisation and sanity correction."""
        if self.model is None:
            raise ModelLoadError("Model not loaded. Call load_model() first.")
        try:
            fv = self._prepare_features(features)
            fv = np.asarray(fv, dtype=float)

            # ---- microphone/scale normalisation ----
            # Temporarily disabled to fix bias - features are already normalized in training
            # fv = np.tanh(fv / 5.0)
            # fv = (fv - np.min(fv)) / ((np.max(fv) - np.min(fv)) + 1e-9)
            # fv = (fv - fv.mean()) / (fv.std() + 1e-6)
            # ----------------------------------------

            pred_proba = self.model.predict_proba([fv])[0]
            pred_class = int(self.model.predict([fv])[0])
            adjusted = self._adjust_predictions_with_cough_indicators(
                features, pred_proba.copy()
            )
            adjusted /= np.sum(adjusted)

            confidence = float(np.max(adjusted))
            predicted_idx = int(np.argmax(adjusted))
            predicted_label = self.inv_label_map.get(predicted_idx, "Unknown")

            # Use direct argmax for predicted_class - no arbitrary remapping
            class_probs = {
                self.inv_label_map.get(i, f"class_{i}"): float(p)
                for i, p in enumerate(adjusted)
            }

            logger.info(
                f"Predicted: {predicted_label} ({confidence:.3f})"
            )

            return {
                "predicted_class": predicted_label,
                "confidence": confidence,
                "class_probs": class_probs,
            }

        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            raise

    # -------------------------------------------------------
    def _adjust_predictions_with_cough_indicators(
        self, features: Dict[str, Any], probs: np.ndarray
    ) -> np.ndarray:
        """Mild heuristic; only adjusts slightly if strong cough."""
        try:
            cough_ratio = features.get("cough_event_ratio", 0.0)
            freq_ratio = features.get("cough_frequency_ratio", 0.0)
            energy_var = features.get("energy_variation", 0.0)
            onset_rate = features.get("onset_rate", 0.0)
            harsh_ratio = features.get("harsh_sound_ratio", 0.0)
            signal_strength = features.get("signal_strength", 0.0)

            cough_score = (
                (cough_ratio / 0.08) * 0.25
                + (freq_ratio / 0.8) * 0.25
                + min(energy_var / 2.0, 1.0) * 0.3
                + min(onset_rate / 3.0, 1.0) * 0.2
            )
            cough_score = float(min(cough_score, 1.0))

            normal_score = (
                (1 - min(cough_ratio / 0.08, 1.0)) * 0.25
                + (1 - min(harsh_ratio / 0.2, 1.0)) * 0.25
                + min(signal_strength / 0.003, 1.0) * 0.25
                + (1 - min(energy_var / 2.0, 1.0)) * 0.25
            )
            normal_score = float(min(normal_score, 1.0))

            healthy_idx = next(
                (i for i, v in self.inv_label_map.items() if v == "Healthy"), None
            )

            if cough_score >= 0.85 and healthy_idx is not None:
                healthy_prob = probs[healthy_idx]
                probs[healthy_idx] = healthy_prob * 0.8
                redistribute = healthy_prob * 0.2
                resp_indices = [
                    i
                    for i, v in self.inv_label_map.items()
                    if v
                    in [
                        "Asthma",
                        "Bronchiectasis",
                        "Bronchiolitis",
                        "COPD",
                        "LRTI",
                        "Pneumonia",
                        "URTI",
                    ]
                ]
                if resp_indices:
                    inc = redistribute / len(resp_indices)
                    for i in resp_indices:
                        probs[i] += inc
                logger.info(f"Cough detected ({cough_score:.2f}) – mild redistribution")

            elif normal_score >= 0.8 and healthy_idx is not None:
                probs[healthy_idx] = min(probs[healthy_idx] + 0.05, 0.8)
                logger.info(f"Normal breathing indicators strong ({normal_score:.2f})")

            probs /= np.sum(probs)

        except Exception as e:
            logger.warning(f"Adjustment skipped: {e}")

        return probs

    # -------------------------------------------------------
    def _prepare_features(self, features: Dict[str, Any]) -> np.ndarray:
        if "model_features" not in features:
            raise ValueError("model_features missing in request")
        fv = np.array(features["model_features"], dtype=float)
        if fv.ndim > 1:
            fv = fv.flatten()
        if len(fv) < 120:
            fv = np.pad(fv, (0, 120 - len(fv)))
        elif len(fv) > 120:
            fv = fv[:120]
        return fv
