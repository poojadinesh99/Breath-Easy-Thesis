import pytest
from fastapi.testclient import TestClient
import tempfile
import os
from unittest.mock import patch, MagicMock

from backend.fastapi_app_improved import app

client = TestClient(app)

@pytest.fixture
def sample_audio_file():
    """Create a temporary WAV file for testing"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        # Create minimal WAV file content
        tmp.write(b'RIFF\x26\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x44\xac\x00\x00\x88X\x01\x00\x02\x00\x10\x00data\x02\x00\x00\x00\x00\x00')
        tmp.flush()
        yield tmp.name
    os.unlink(tmp.name)

class TestPredictUnifiedEndpoint:
    def test_predict_unified_with_file_upload(self, sample_audio_file):
        """Test POST /predict/unified with file upload"""
        with open(sample_audio_file, 'rb') as f:
            response = client.post(
                "/predict/unified",
                files={"file": ("test.wav", f, "audio/wav")}
            )
        assert response.status_code == 200
        data = response.json()
        assert "label" in data
        assert "confidence" in data
        assert "source" in data
        assert "processing_time" in data

    def test_predict_unified_with_audio_url(self):
        """Test POST /predict/unified with audio URL"""
        with patch('requests.get') as mock_get:
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.iter_content.return_value = [b'test_data']
            mock_get.return_value = mock_response
            response = client.post(
                "/predict/unified",
                data={"audio_url": "https://example.com/test.wav"}
            )
        assert response.status_code == 200
        data = response.json()
        assert "label" in data

    def test_predict_unified_no_input(self):
        """Test POST /predict/unified with no input"""
        response = client.post("/predict/unified")
        assert response.status_code == 400
        data = response.json()
        assert data["error"] == "No audio provided (file or URL)."

    def test_health(self):
        """Test GET /health"""
        r = client.get("/health")
        assert r.status_code == 200
        data = r.json()
        assert "status" in data
