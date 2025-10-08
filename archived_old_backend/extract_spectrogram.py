import sys
import numpy as np
import librosa

def extract_features(audio_path: str) -> np.ndarray:
    """
    Extracts audio features from a WAV file to match the model's expected input:
    - 13 MFCC coefficients
    - 26 Mel spectrogram bands
    Total: 39 features (13 + 26 = 39)
    
    Parameters:
        audio_path (str): Path to the WAV audio file.
    
    Returns:
        np.ndarray: Feature array of shape (1, 39) for model input.
    """
    try:
        # Load audio with native sampling rate
        y, sr = librosa.load(audio_path, sr=None, mono=True)
    except Exception as e:
        raise RuntimeError(f"Error loading audio file {audio_path}: {e}")

    # Extract 13 MFCC coefficients
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, n_fft=2048, hop_length=512, fmax=8000)
    
    # Extract Mel spectrogram with 26 bands (to match 39 total features)
    mel_spec = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=26, n_fft=2048, hop_length=512, fmax=8000)
    
    # Convert Mel spectrogram to log scale (dB)
    log_mel_spec = librosa.power_to_db(mel_spec, ref=np.max)
    
    # Compute mean across time frames (axis=1)
    mfcc_mean = np.mean(mfcc, axis=1)
    log_mel_mean = np.mean(log_mel_spec, axis=1)
    
    # Concatenate all features into a single 1D array
    features = np.concatenate([mfcc_mean, log_mel_mean])
    
    # Ensure we have exactly 39 features
    if len(features) != 39:
        # Pad or truncate to 39 features
        if len(features) < 39:
            features = np.pad(features, (0, 39 - len(features)), mode='constant')
        else:
            features = features[:39]
    
    # Reshape to (1, 39) for model input
    features = features.reshape(1, -1)
    
    return features

def extract_spectrogram(wav_path):
    """Legacy function - use extract_features instead"""
    return extract_features(wav_path)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 extract_spectrogram.py <path_to_wav>")
        sys.exit(1)

    wav_path = sys.argv[1]
    features = extract_features(wav_path)
    print(f"Extracted features shape: {features.shape}")
    print(f"Feature values: {features[0][:10]}...")  # Show first 10 values
