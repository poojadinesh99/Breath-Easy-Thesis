import requests

# Your Hugging Face Space API URL
HF_API_URL = "https://hf.space/embed/PoojaDinesh99/breathe-easy-dualnet/api/predict/"

# Path to your local audio file to test
AUDIO_FILE_PATH = "path/to/your/test_audio.wav"

def test_hf_inference():
    with open(AUDIO_FILE_PATH, "rb") as audio_file:
        files = {"data": audio_file}  # The key 'data' might vary based on your HF Space input schema
        response = requests.post(HF_API_URL, files=files)
    if response.status_code == 200:
        print("Prediction response:", response.json())
    else:
        print("Error:", response.status_code, response.text)

if __name__ == "__main__":
    test_hf_inference()
