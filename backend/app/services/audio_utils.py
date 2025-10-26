"""
Audio utilities for normalizing and validating audio files.
Handles conversion to 16kHz mono WAV and provides fallback options.
"""
import os
import subprocess
import tempfile
from pathlib import Path
import logging
import wave
import numpy as np
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

class AudioNormalizationError(Exception):
    """Custom exception for audio normalization failures."""
    pass

def check_ffmpeg_available() -> bool:
    """Check if ffmpeg is available in the system."""
    try:
        subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
        return True
    except (subprocess.SubprocessError, FileNotFoundError):
        return False

def get_wav_duration(file_path: str) -> float:
    """Get the duration of a WAV file in seconds."""
    try:
        with wave.open(file_path, 'rb') as wav_file:
            frames = wav_file.getnframes()
            rate = wav_file.getframerate()
            duration = frames / float(rate)
            return duration
    except Exception as e:
        logger.error(f"Error getting WAV duration: {e}")
        raise AudioNormalizationError(f"Invalid WAV file: {e}")

def normalize_audio(input_path: str, min_duration: float = 0.5) -> Tuple[str, float]:
    """
    Normalize audio to 16kHz mono WAV format using ffmpeg.
    Falls back to wave module if ffmpeg is not available.
    
    Args:
        input_path: Path to input audio file
        min_duration: Minimum required duration in seconds
    
    Returns:
        Tuple[str, float]: (Path to normalized audio, duration in seconds)
    
    Raises:
        AudioNormalizationError: If normalization fails or audio is too short
    """
    if not os.path.exists(input_path):
        raise AudioNormalizationError(f"Input file not found: {input_path}")

    # Create temp file for normalized audio
    temp_dir = tempfile.mkdtemp()
    output_path = os.path.join(temp_dir, 'normalized.wav')
    
    try:
        if check_ffmpeg_available():
            # Use ffmpeg for conversion (preferred method)
            cmd = [
                'ffmpeg', '-y',
                '-i', input_path,
                '-acodec', 'pcm_s16le',
                '-ar', '16000',
                '-ac', '1',
                output_path
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            if result.returncode != 0:
                raise AudioNormalizationError(
                    f"FFmpeg conversion failed: {result.stderr}"
                )
        else:
            # Fallback: Use wave module for basic WAV handling
            logger.warning("FFmpeg not found, using fallback wave module")
            with wave.open(input_path, 'rb') as wav_in:
                # Read original audio
                frames = wav_in.readframes(wav_in.getnframes())
                
                # Convert to numpy array
                audio_data = np.frombuffer(frames, dtype=np.int16)
                
                # If stereo, convert to mono by averaging channels
                if wav_in.getnchannels() == 2:
                    audio_data = audio_data.reshape(-1, 2).mean(axis=1)
                
                # Resample to 16kHz if needed
                if wav_in.getframerate() != 16000:
                    # Basic linear resampling (not ideal but works as fallback)
                    original_length = len(audio_data)
                    target_length = int(original_length * 16000 / wav_in.getframerate())
                    indices = np.linspace(0, original_length-1, target_length)
                    audio_data = np.interp(indices, np.arange(original_length), audio_data)
                
                # Write normalized audio
                with wave.open(output_path, 'wb') as wav_out:
                    wav_out.setnchannels(1)
                    wav_out.setsampwidth(2)
                    wav_out.setframerate(16000)
                    wav_out.writeframes(audio_data.astype(np.int16).tobytes())

        # Check duration
        duration = get_wav_duration(output_path)
        if duration < min_duration:
            raise AudioNormalizationError(
                f"Audio too short: {duration:.2f}s (minimum: {min_duration}s)"
            )
            
        return output_path, duration
        
    except Exception as e:
        if os.path.exists(output_path):
            os.remove(output_path)
        raise AudioNormalizationError(f"Audio normalization failed: {str(e)}")
