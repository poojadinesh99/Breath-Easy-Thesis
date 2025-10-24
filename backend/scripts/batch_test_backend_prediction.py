import requests
import os
import argparse

def batch_test(wav_dir, url, task_type):
    wav_files = [f for f in os.listdir(wav_dir) if f.endswith('.wav')]
    for wav_file in wav_files:
        path = os.path.join(wav_dir, wav_file)
        with open(path, 'rb') as f:
            files = {'file': (wav_file, f, 'audio/wav')}
            data = {'task_type': task_type}
            try:
                response = requests.post(url, files=files, data=data, timeout=30)
                result = response.json()
                label = result.get('label', 'N/A')
                confidence = result.get('confidence', 'N/A')
                print(f"{wav_file}: {label} ({confidence})")
            except Exception as e:
                print(f"{wav_file}: Error - {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Batch test backend prediction API with WAV files.")
    parser.add_argument('--wav_dir', required=True, help='Directory with WAV files to test')
    parser.add_argument('--url', required=True, help='Backend prediction endpoint URL')
    parser.add_argument('--task_type', required=True, help='Task type (e.g., breath, speech)')
    args = parser.parse_args()
    batch_test(args.wav_dir, args.url, args.task_type)
