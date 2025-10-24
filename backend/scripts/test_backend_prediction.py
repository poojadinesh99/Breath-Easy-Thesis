import requests
import argparse
import os

# Example usage:
# python3 test_backend_prediction.py --wav_file ./backend/data/voiced_wavs/voice001.wav --url http://127.0.0.1:8000/api/v1/unified --task_type breath

def test_prediction(wav_file, url, task_type):
    with open(wav_file, 'rb') as f:
        files = {'file': (os.path.basename(wav_file), f, 'audio/wav')}
        data = {'task_type': task_type}
        response = requests.post(url, files=files, data=data)
    print(f"Response for {wav_file}:")
    print(response.status_code)
    print(response.text)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test backend prediction API with a WAV file.")
    parser.add_argument('--wav_file', required=True, help='Path to WAV file to test')
    parser.add_argument('--url', required=True, help='Backend prediction endpoint URL')
    parser.add_argument('--task_type', required=True, help='Task type (e.g., breath, speech)')
    args = parser.parse_args()
    test_prediction(args.wav_file, args.url, args.task_type)
