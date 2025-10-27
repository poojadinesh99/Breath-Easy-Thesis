"""
Service for analyzing audio files and generating predictions.
Handles both breath and speech analysis with proper audio normalization.
"""
import os
import logging
from typing import Dict, Any
import time
from fastapi import HTTPException

from .audio_utils import normalize_audio, AudioNormalizationError
from .feature_extraction import extract_features
from .model_service import ModelService
from .supabase_service import SupabaseService

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

    async def analyze_audio(
        self,
        file_path: str,
        task_type: str = "breath",
        min_duration: float = 0.5
    ) -> Dict[str, Any]:
        """Analyze an audio file and return predictions."""
        if not self.initialized:
            try:
                self.model_service.load_model()
                self.initialized = True
            except Exception as e:
                logger.warning(f"Model not available: {e}")
                return {
                    "predictions": {"clear": 1.0},
                    "label": "clear",
                    "confidence": 1.0,
                    "source": "demo_fallback",
                    "processing_time": 0.0,
                    "text_summary": "Demo mode: Detected clear breathing (model unavailable)."
                }

        try:
            start_time = time.time()
            normalized_path, duration = normalize_audio(file_path, min_duration=min_duration)
            features = extract_features(normalized_path, task_type)
            os.remove(normalized_path)

            predictions = self.model_service.predict(features)
            class_probs = predictions.get("class_probs", {})
            logger.info(f"Raw model output: {class_probs}")

            # --- ⚖️ Rebalance prediction bias ---
            rebalance_factors = {
                "cough": 2.5,
                "throat_clearing": 2.2,
                "normal": 1.0,
                "heavy_breathing": 0.6
            }
            for cls, factor in rebalance_factors.items():
                if cls in class_probs:
                    class_probs[cls] *= factor
            total = sum(class_probs.values())
            if total > 0:
                class_probs = {k: v / total for k, v in class_probs.items()}

            label = max(class_probs, key=class_probs.get)
            confidence = class_probs[label]
            logger.info(f"Adjusted model predicted: {label} ({confidence:.2f})")

            # --- Extract key acoustic features ---
            energy_var = float(features.get("energy_variation", 0.0))
            onset_rate = float(features.get("onset_rate", 0.0))
            harsh_ratio = float(features.get("harsh_sound_ratio", 0.0))
            logger.info(f"Energy={energy_var:.2f}, Onset={onset_rate:.2f}, Harsh={harsh_ratio:.2f}")

            # --- 🩺 Fix false heavy_breathing for calm breathing ---
            if label == "heavy_breathing" and energy_var < 2.0 and onset_rate < 3.5:
                logger.info("🫁 Adjusted calm heavy_breathing → normal (stable low energy pattern)")
                label = "normal"
                confidence = 0.9

            # --- 💥 Unified Cough vs Throat Clearing rule ---
            if 2.3 <= energy_var <= 3.5 and onset_rate < 3.5:
                if harsh_ratio >= 0.10:
                    logger.info("💥 Adjusted to cough (moderate–high energy short burst)")
                    label = "cough"
                    confidence = 0.88
                elif 0.05 <= harsh_ratio < 0.10:
                    logger.info("🔄 Adjusted to throat_clearing (mild energy, low harshness)")
                    label = "throat_clearing"
                    confidence = 0.84

            # --- 🎙️ Speech-specific correction ---
            if task_type == "speech":
                if energy_var > 1.5 and harsh_ratio > 0.1 and onset_rate < 3.5:
                    logger.info("🎙️ Adjusted speech burst → cough (speech context)")
                    label = "cough"
                    confidence = 0.85
                elif 1.0 < energy_var < 2.2 and 3.0 <= onset_rate <= 4.0 and harsh_ratio < 0.15:
                    logger.info("🎙️ Adjusted speech segment → throat_clearing")
                    label = "throat_clearing"
                    confidence = 0.83

            # --- 🧠 Map symptom to likely conditions ---
            disease_map = {
                "cough": ["URTI", "Bronchitis", "Post-COVID irritation"],
                "heavy_breathing": ["COPD", "Asthma", "Pneumonia"],
                "throat_clearing": ["Post-COVID", "Allergy", "Reflux"],
                "abnormal": ["Bronchiectasis", "COPD", "Pneumonia"],
                "normal": ["Healthy"]
            }
            possible_conditions = disease_map.get(label.lower(), ["Unspecified"])
            disease_hint = ", ".join(possible_conditions)

            # --- 🧾 Generate summary ---
            summary = self._generate_summary(
                {"predicted_class": label, "confidence": confidence, "transcription": features.get("transcription", "")},
                task_type,
                duration,
                disease_hint
            )

            result = {
                "predictions": class_probs,
                "label": label,
                "simplified_label": label,
                "confidence": confidence,
                "possible_conditions": possible_conditions,
                "source": "local",
                "processing_time": time.time() - start_time,
                "text_summary": summary,
                "original_label": label,
                "low_confidence": confidence < 0.75
            }

            try:
                await self.supabase_service.save_analysis_result(
                    result,
                    {"file_path": file_path, "task_type": task_type, "duration": duration}
                )
            except Exception as e:
                logger.warning(f"Supabase save failed: {e}")

            return result

        except AudioNormalizationError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            logger.error(f"Analysis failed: {e}")
            return {
                "predictions": {"error": 1.0},
                "label": "uncertain",
                "confidence": 0.0,
                "source": "error_fallback",
                "processing_time": 0.0,
                "text_summary": f"❌ Analysis failed: {e}"
            }

    def _generate_summary(
        self,
        predictions: Dict[str, Any],
        task_type: str,
        duration: float,
        disease_hint: str = ""
    ) -> str:
        """Generate a user-friendly summary."""
        label = predictions.get("predicted_class", "Unknown")
        confidence = predictions.get("confidence", 0.0)

        emojis = {
            "normal": "✅",
            "cough": "🤧",
            "throat_clearing": "🗣️",
            "heavy_breathing": "⚠️",
        }
        emoji = emojis.get(label, "🔍")
        msg = label.replace("_", " ").title()

        summary = (
            f"{emoji} Detected **{msg}** pattern "
            f"with {confidence*100:.1f}% confidence.\n"
            f"💡 Possible associated conditions: {disease_hint}.\n"
            f"⚙️ Note: This mapping is heuristic — confirm with clinical diagnosis.\n\n"
            f"🩺 Prototype AI system — not a medical device."
        )
        return summary
