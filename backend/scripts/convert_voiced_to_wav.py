import os
import numpy as np
from scipy.io import wavfile
import argparse

# Helper to parse .hea header for sample rate

def parse_header(header_path):
    with open(header_path, 'r') as f:
        lines = f.readlines()
    for line in lines:
        if 'Sampling frequency' in line or 'sampling frequency' in line:
            # Example: "Sampling frequency: 8000 Hz"
            parts = line.split(':')
            if len(parts) > 1:
                freq = parts[1].strip().split(' ')[0]
                return int(freq)
        if line.strip().isdigit():
            # Sometimes first line is just the sample rate
            return int(line.strip())
    # Default to 8000 Hz if not found
    return 8000

# Convert .txt signal to numpy array

def read_signal(txt_path):
    with open(txt_path, 'r') as f:
        data = f.read().split()
    # Convert to int16
    arr = np.array(data, dtype=np.int16)
    return arr

# Main conversion function

def convert_voiced_folder(input_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    for fname in os.listdir(input_dir):
        if fname.endswith('.hea'):
            base = fname[:-4]
            hea_path = os.path.join(input_dir, base + '.hea')
            txt_path = os.path.join(input_dir, base + '.txt')
            if os.path.exists(txt_path):
                sr = parse_header(hea_path)
                signal = read_signal(txt_path)
                wav_path = os.path.join(output_dir, base + '.wav')
                wavfile.write(wav_path, sr, signal)
                print(f"Converted {base} to WAV at {wav_path}")
            else:
                print(f"Missing .txt for {base}, skipping.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert VOICED .hea/.txt files to WAV.")
    parser.add_argument('--input_dir', required=True, help='Path to folder with .hea/.txt files')
    parser.add_argument('--output_dir', required=True, help='Path to save .wav files')
    args = parser.parse_args()
    convert_voiced_folder(args.input_dir, args.output_dir)
