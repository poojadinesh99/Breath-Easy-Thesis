
import os
import logging
from supabase import create_client, Client
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SupabaseService:
    """
    Service for interacting with Supabase for research data management.
    
    This class handles the connection to Supabase and provides methods for
    storing analysis results, contributing to the research-grade nature of the project.
    """
    _client: Optional[Client] = None

    def __init__(self, url: str, key: str):
        if url and key:
            try:
                self._client = create_client(url, key)
                logger.info("🎓 Supabase client initialized successfully.")
            except Exception as e:
                logger.error(f"🔥 Failed to initialize Supabase client: {e}")
        else:
            logger.warning("⚠️ Supabase URL or Key not provided. SupabaseService will be disabled.")

    def log_analysis(self, analysis_result: Dict[str, Any], audio_metadata: Dict[str, Any] = None):
        """
        Logs a single analysis result to the 'analysis_history' table in Supabase.
        
        This function is crucial for the thesis as it creates a dataset of results
        that can be used for further analysis, model performance tracking, and demonstrating
        the practical application of the research.
        
        Args:
            analysis_result (Dict[str, Any]): The dictionary containing the prediction,
                                              confidence, and other metadata.
            audio_metadata (Dict[str, Any], optional): Metadata about the audio file.
        """
        if not self._client:
            logger.warning("Supabase client not available. Skipping data logging.")
            return

        try:
            research_data = {
                "analysis_type": "unified_v2",
                "predicted_label": analysis_result.get("label"),
                "confidence": float(analysis_result.get("confidence", 0)),
                "extra": {
                    "processing_time": analysis_result.get("processing_time"),
                    "source": analysis_result.get("source"),
                    "features_extracted": analysis_result.get("features_count", 0),
                    "audio_metadata": audio_metadata or {},
                    "research_details": analysis_result.get("research_analysis", {})
                },
                # 'created_at' is now automatically handled by Supabase with 'default now()'
            }
            
            # The .execute() call sends the request to the Supabase API
            response = self._client.table("analysis_history").insert(research_data).execute()
            
            logger.info("🎓 Research data successfully logged to Supabase.")
            # You can check response for errors if needed, though it raises exceptions on failure
            if response.data:
                logger.info(f"Log response: {response.data[0]['id']}")

        except Exception as e:
            logger.error(f"🔥 Failed to log research data to Supabase: {e}")

# Example of how to initialize this service in the main application
# from app.core.config import settings
# supabase_service = SupabaseService(url=settings.SUPABASE_URL, key=settings.SUPABASE_KEY)
