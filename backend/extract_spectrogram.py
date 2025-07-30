import sys
import numpy as np
import librosa

def extract_spectrogram(wav_path):
    # Load audio at native sample rate, convert to mono
    y, sr = librosa.load(wav_path, sr=None, mono=True)

    # Remove silence longer than 500 ms (top_db=20)
    intervals = librosa.effects.split(y, top_db=20)

    # Concatenate non-silent intervals
    y_nonsilent = np.concatenate([y[start:end] for start, end in intervals])

    # Split into 1-second segments
    segment_length = sr  # samples per second
    num_segments = int(np.ceil(len(y_nonsilent) / segment_length))

    spectrograms = []

    for i in range(num_segments):
        start = i * segment_length
        end = min((i + 1) * segment_length, len(y_nonsilent))
        segment = y_nonsilent[start:end]

        # Pad segment if shorter than 1 second
        if len(segment) < segment_length:
            segment = np.pad(segment, (0, segment_length - len(segment)), mode='constant')

        # Calculate hop_length to get 64 time frames
        hop_length = int(np.floor((segment_length - 512) / 63))  # 512 is default n_fft

        # Compute log-Mel spectrogram (128 mel bands, 64 time frames)
        S = librosa.feature.melspectrogram(y=segment, sr=sr, n_mels=128, hop_length=hop_length)
        log_S = librosa.power_to_db(S, ref=np.max)

        # Resize or crop to 128x64 if needed
        if log_S.shape[1] > 64:
            log_S = log_S[:, :64]
        elif log_S.shape[1] < 64:
            pad_width = 64 - log_S.shape[1]
            log_S = np.pad(log_S, ((0,0),(0,pad_width)), mode='constant')

        spectrograms.append(log_S)

    spectrograms_array = np.stack(spectrograms)

    # Save numpy array to .npy file
    npy_path = wav_path.rsplit('.', 1)[0] + '_spectrogram.npy'
    np.save(npy_path, spectrograms_array)

    print(list(spectrograms_array.shape))


def extract_features(audio_path: str) -> np.ndarray:
    """
    Extracts audio features from a WAV file:
    - 13 MFCC coefficients
    - 40 Mel spectrogram bands
    Computes mean and std deviation across time frames for both MFCC and log-Mel features,
    concatenates them into a single 1D numpy array, reshaped as (1, feature_length).

    Parameters:
        audio_path (str): Path to the WAV audio file.

    Returns:
        np.ndarray: Feature array of shape (1, feature_length).
    """
    try:
        # Load audio with native sampling rate
        y, sr = librosa.load(audio_path, sr=None, mono=True)
    except Exception as e:
        raise RuntimeError(f"Error loading audio file {audio_path}: {e}")

    # Extract 13 MFCC coefficients
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, n_fft=2048, hop_length=512, fmax=8000)

    # Extract Mel spectrogram with 40 bands
    mel_spec = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=40, n_fft=2048, hop_length=512, fmax=8000)

    # Convert Mel spectrogram to log scale (dB)
    log_mel_spec = librosa.power_to_db(mel_spec, ref=np.max)

    # Compute mean and std across time frames (axis=1)
    mfcc_mean = np.mean(mfcc, axis=1)
    mfcc_std = np.std(mfcc, axis=1)
    log_mel_mean = np.mean(log_mel_spec, axis=1)
    log_mel_std = np.std(log_mel_spec, axis=1)

    # Concatenate all features into a single 1D array
    features = np.concatenate([mfcc_mean, mfcc_std, log_mel_mean, log_mel_std])

    # Reshape to (1, feature_length) for model input
    features = features.reshape(1, -1)

    return features

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python extract_spectrogram.py <path_to_wav>")
        sys.exit(1)

    wav_path = sys.argv[1]
    extract_spectrogram(wav_path)
