"""
Service for analyzing audio files and generating predictions.
Now includes smart input-type detection and dynamic verdict mapping.
"""
import os
import logging
import time
from typing import Dict, Any
from fastapi import HTTPException
import librosa
from .audio_utils import normalize_audio, AudioNormalizationError
from .feature_extraction import extract_features, detect_input_type,detect_task_type
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
            start_time = time.time()
            normalized_path, duration = normalize_audio(file_path, min_duration=min_duration)

            # --- 🎛️ Auto-detect speech vs breath before extracting features ---
            try:
                y, sr = librosa.load(file_path, sr=16000)
                auto_task = detect_task_type(y, sr)
                if task_type != auto_task:
                    logger.info(f"🎛️ Auto-switched task type: {task_type} → {auto_task}")
                    task_type = auto_task
            except Exception as e:
                logger.warning(f"Auto task detection failed: {e}")

            # --- Now continue with feature extraction ---
            features = extract_features(normalized_path, task_type)
            os.remove(normalized_path)


            # --- 🔍 Model prediction ---
            predictions = self.model_service.predict(features)
            class_probs = predictions.get("class_probs", {})
            label = max(class_probs, key=class_probs.get)
            confidence = class_probs[label]
            logger.info(f"Raw model output: {class_probs}")

            # --- ⚖️ Rebalance class bias ---
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

            # --- 🧠 Step 1: Auto-detect acoustic input type ---
            logger.info(f"About to call detect_input_type with features keys: {list(features.keys())}")
            detected_type = detect_input_type(features)
            logger.info(f"🧩 Auto-detected input type: {detected_type}")

            # --- Step 2: Force override model prediction with detected type for better accuracy ---
            # The ML model is biased toward heavy_breathing, so we trust the rule-based detection more
            # Especially prioritize cough detection when rule-based detection finds it
            if detected_type == "cough":
                logger.info(f"⚖️ Strong cough detected - overriding model prediction ({label}) → detected ({detected_type})")
                label = detected_type
                confidence = max(confidence, 0.90)  # Higher confidence for cough detection
            elif detected_type != "normal":
                logger.info(f"⚖️ Overriding model prediction ({label}) → detected ({detected_type})")
                label = detected_type
                confidence = max(confidence, 0.85)
            elif confidence < 0.65:
                logger.info(f"⚖️ Low confidence, using detected type ({detected_type})")
                label = detected_type
                confidence = max(confidence, 0.82)

            # --- 🎯 Step 3: Map to likely conditions ---
            disease_map = {
                "cough": ["URTI", "Bronchitis", "Post-COVID irritation"],
                "heavy_breathing": ["COPD", "Asthma", "Pneumonia"],
                "throat_clearing": ["Post-COVID", "Allergy", "Reflux"],
                "normal": ["Healthy"]
            }
            possible_conditions = disease_map.get(label.lower(), ["Unspecified"])

            # --- 🩺 Step 4: Human-friendly verdict ---
            verdict_map = {
                "cough": "🤧 Detected cough pattern — possible bronchitis, infection, or post-COVID irritation.",
                "heavy_breathing": "⚠️ Detected heavy breathing — may indicate asthma, COPD, or exertion.",
                "throat_clearing": "🗣️ Detected throat clearing — may relate to allergy, reflux, or mild irritation.",
                "normal": "✅ Normal breathing pattern detected — no abnormality found.",
            }
            verdict_text = verdict_map.get(label, "🔍 Uncertain pattern — please retest or check mic clarity.")

            # --- 🧾 Step 5: Summary for UI ---
            summary = (
                f"{verdict_text}\n\n"
                f"💡 Confidence: {confidence*100:.1f}%\n"
                f"🩺 Possible associated conditions: {', '.join(possible_conditions)}.\n"
                f"⚙️ Note: Prototype AI — not a medical device."
            )

            result = {
                "predictions": class_probs,
                "label": label,
                "simplified_label": label,
                "confidence": confidence,
                "possible_conditions": possible_conditions,
                "verdict": verdict_text,
                "source": "local",
                "processing_time": time.time() - start_time,
                "text_summary": summary,
                "low_confidence": confidence < 0.75
            }

            # --- 💾 Optional: Supabase Logging ---
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
