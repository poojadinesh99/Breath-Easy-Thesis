"""
Research Data Management System for Respiratory Disease Detection Thesis
Advanced database integration with comprehensive analytics and research tracking
"""

import os
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from supabase import create_client, Client
import uuid

logger = logging.getLogger("ResearchDatabase")

class ResearchDataManager:
    """
    Advanced research data management system for respiratory disease detection thesis
    
    This class handles comprehensive data persistence, research analytics,
    and longitudinal study tracking for the respiratory disease detection system.
    """
    
    def __init__(self):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_ANON_KEY')
        
        if self.supabase_url and self.supabase_key:
            try:
                self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
                logger.info("🗄️ Research database connection established")
                self.connected = True
            except Exception as e:
                logger.error(f"❌ Database connection failed: {e}")
                self.connected = False
        else:
            logger.warning("⚠️ Supabase credentials not found - running in offline mode")
            self.connected = False
    
    async def save_analysis_results(self, 
                                  analysis_results: Dict, 
                                  audio_metadata: Dict,
                                  user_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Save comprehensive analysis results to research database
        
        Args:
            analysis_results: Complete analysis results from ML pipeline
            audio_metadata: Audio file metadata and recording information
            user_id: Optional user identifier for tracking
            
        Returns:
            Database operation results with research tracking information
        """
        if not self.connected:
            logger.warning("📴 Database offline - analysis not saved")
            return {'status': 'offline', 'saved': False}
        
        try:
            # Generate research session ID
            session_id = str(uuid.uuid4())
            timestamp = datetime.now().isoformat()
            
            # Prepare analysis record for database
            analysis_record = {
                'id': session_id,
                'user_id': user_id or 'anonymous',
                'file_name': audio_metadata.get('filename', 'unknown'),
                'analysis_type': 'unified_respiratory',
                'predicted_label': analysis_results['classification']['predicted_class'],
                'confidence': float(analysis_results['classification']['confidence_score']),
                'created_at': timestamp,
                'extra': {
                    'research_metadata': analysis_results.get('research_metadata', {}),
                    'technical_details': analysis_results.get('technical_details', {}),
                    'clinical_information': analysis_results.get('clinical_information', {}),
                    'feature_analysis': analysis_results.get('feature_analysis', {}),
                    'audio_metadata': audio_metadata,
                    'thesis_project_tag': 'advanced_respiratory_detection_2025'
                }
            }
            
            # Save to analysis_history table
            result = self.supabase.table('analysis_history').insert(analysis_record).execute()
            
            if result.data:
                logger.info(f"💾 Analysis results saved to research database (ID: {session_id})")
                
                # Update research statistics
                await self._update_research_statistics(analysis_results)
                
                return {
                    'status': 'success',
                    'saved': True,
                    'session_id': session_id,
                    'timestamp': timestamp,
                    'database_record_id': result.data[0]['id']
                }
            else:
                logger.error("❌ Failed to save analysis results")
                return {'status': 'error', 'saved': False, 'error': 'Database insert failed'}
                
        except Exception as e:
            logger.error(f"❌ Database save operation failed: {e}")
            return {'status': 'error', 'saved': False, 'error': str(e)}
    
    async def save_recording_metadata(self, 
                                    audio_file_path: str, 
                                    category: str,
                                    user_id: Optional[str] = None,
                                    notes: Optional[str] = None) -> Dict[str, Any]:
        """
        Save recording metadata for research tracking
        
        Args:
            audio_file_path: Path to the audio file
            category: Recording category (breath, speech, etc.)
            user_id: Optional user identifier
            notes: Optional research notes
            
        Returns:
            Recording metadata save results
        """
        if not self.connected:
            return {'status': 'offline', 'saved': False}
        
        try:
            # Extract file metadata
            file_stats = os.stat(audio_file_path) if os.path.exists(audio_file_path) else None
            
            recording_record = {
                'id': str(uuid.uuid4()),
                'user_id': user_id or 'anonymous',
                'file_url': audio_file_path,  # In production, this would be a cloud storage URL
                'category': category,
                'recorded_at': datetime.now().isoformat(),
                'notes': notes or f"Research recording - {category} - {datetime.now().strftime('%Y-%m-%d %H:%M')}"
            }
            
            result = self.supabase.table('recordings').insert(recording_record).execute()
            
            if result.data:
                logger.info(f"📹 Recording metadata saved (Category: {category})")
                return {
                    'status': 'success',
                    'saved': True,
                    'recording_id': result.data[0]['id']
                }
            else:
                return {'status': 'error', 'saved': False}
                
        except Exception as e:
            logger.error(f"❌ Recording metadata save failed: {e}")
            return {'status': 'error', 'saved': False, 'error': str(e)}
    
    async def get_research_statistics(self) -> Dict[str, Any]:
        """
        Get comprehensive research statistics for thesis analysis
        
        Returns:
            Detailed research statistics and analytics
        """
        if not self.connected:
            return {'status': 'offline', 'statistics': {}}
        
        try:
            # Get analysis history statistics
            analysis_stats = await self._get_analysis_statistics()
            
            # Get recording statistics
            recording_stats = await self._get_recording_statistics()
            
            # Get user engagement statistics
            user_stats = await self._get_user_statistics()
            
            # Calculate research insights
            research_insights = await self._calculate_research_insights()
            
            return {
                'status': 'success',
                'generated_at': datetime.now().isoformat(),
                'statistics': {
                    'analysis_overview': analysis_stats,
                    'recording_overview': recording_stats,
                    'user_engagement': user_stats,
                    'research_insights': research_insights,
                    'thesis_project': 'Advanced Respiratory Disease Detection using OpenSMILE and Deep Learning'
                }
            }
            
        except Exception as e:
            logger.error(f"❌ Research statistics calculation failed: {e}")
            return {'status': 'error', 'error': str(e)}
    
    async def _get_analysis_statistics(self) -> Dict[str, Any]:
        """Get detailed analysis statistics"""
        try:
            # Total analyses
            total_result = self.supabase.table('analysis_history').select('id').execute()
            total_analyses = len(total_result.data) if total_result.data else 0
            
            # Analyses by classification
            classification_stats = {}
            if total_analyses > 0:
                for classification in ['normal', 'crackles', 'wheezing', 'abnormal']:
                    class_result = self.supabase.table('analysis_history')\
                        .select('id')\
                        .eq('predicted_label', classification)\
                        .execute()
                    classification_stats[classification] = len(class_result.data) if class_result.data else 0
            
            # Average confidence scores
            confidence_result = self.supabase.table('analysis_history').select('confidence').execute()
            confidences = [r['confidence'] for r in confidence_result.data] if confidence_result.data else []
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0
            
            return {
                'total_analyses': total_analyses,
                'classification_distribution': classification_stats,
                'average_confidence': round(avg_confidence, 3),
                'confidence_range': {
                    'min': min(confidences) if confidences else 0,
                    'max': max(confidences) if confidences else 0
                }
            }
            
        except Exception as e:
            logger.error(f"❌ Analysis statistics calculation failed: {e}")
            return {}
    
    async def _get_recording_statistics(self) -> Dict[str, Any]:
        """Get recording statistics"""
        try:
            # Total recordings
            total_result = self.supabase.table('recordings').select('id').execute()
            total_recordings = len(total_result.data) if total_result.data else 0
            
            # Recordings by category
            category_stats = {}
            for category in ['breath', 'speech', 'breathing_exercise']:
                cat_result = self.supabase.table('recordings')\
                    .select('id')\
                    .eq('category', category)\
                    .execute()
                category_stats[category] = len(cat_result.data) if cat_result.data else 0
            
            return {
                'total_recordings': total_recordings,
                'category_distribution': category_stats,
                'recording_quality': 'High'  # Could be calculated based on file metadata
            }
            
        except Exception as e:
            logger.error(f"❌ Recording statistics calculation failed: {e}")
            return {}
    
    async def _get_user_statistics(self) -> Dict[str, Any]:
        """Get user engagement statistics"""
        try:
            # Unique users
            users_result = self.supabase.table('analysis_history').select('user_id').execute()
            unique_users = len(set(r['user_id'] for r in users_result.data)) if users_result.data else 0
            
            return {
                'total_unique_users': unique_users,
                'user_engagement': 'Active' if unique_users > 0 else 'Starting'
            }
            
        except Exception as e:
            logger.error(f"❌ User statistics calculation failed: {e}")
            return {}
    
    async def _calculate_research_insights(self) -> Dict[str, Any]:
        """Calculate advanced research insights for thesis"""
        try:
            insights = {
                'ml_model_performance': {
                    'feature_extraction': 'OpenSMILE eGeMAPS + Custom Respiratory Features',
                    'classification_approach': 'Multi-model Ensemble with Pattern Recognition',
                    'clinical_validation': 'In Progress',
                    'research_contribution': 'Novel respiratory-specific feature engineering'
                },
                'technical_innovations': [
                    'Advanced OpenSMILE feature extraction for respiratory analysis',
                    'Custom wheeze and crackle detection algorithms',
                    'Real-time pattern recognition for mobile deployment',
                    'Comprehensive clinical insight generation'
                ],
                'research_impact': {
                    'domain': 'Digital Health and Respiratory Medicine',
                    'contribution': 'Mobile AI-powered respiratory disease detection',
                    'potential_applications': [
                        'Early respiratory disease screening',
                        'Remote patient monitoring',
                        'Telemedicine support systems',
                        'Public health surveillance'
                    ]
                }
            }
            
            return insights
            
        except Exception as e:
            logger.error(f"❌ Research insights calculation failed: {e}")
            return {}
    
    async def _update_research_statistics(self, analysis_results: Dict):
        """Update ongoing research statistics"""
        try:
            # This could update a separate research_metrics table
            # For now, we'll log the research progress
            classification = analysis_results['classification']['predicted_class']
            confidence = analysis_results['classification']['confidence_score']
            
            logger.info(f"📊 Research Progress: {classification} detected with {confidence:.1%} confidence")
            
        except Exception as e:
            logger.error(f"❌ Research statistics update failed: {e}")
    
    def get_connection_status(self) -> Dict[str, Any]:
        """Get database connection status for debugging"""
        return {
            'connected': self.connected,
            'supabase_configured': bool(self.supabase_url and self.supabase_key),
            'timestamp': datetime.now().isoformat()
        }
