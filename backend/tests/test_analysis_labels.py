import os
import asyncio
import pytest

from backend.app.services.analysis_service import AnalysisService


TEST_DIR = os.path.dirname(__file__)


async def _analyze(path: str, task: str = "breath"):
    svc = AnalysisService()
    return await svc.analyze_audio(path, task_type=task)


@pytest.mark.asyncio
async def test_cough_label_stability():
    """Cough sample should classify as cough with high confidence."""
    sample = os.path.join(TEST_DIR, "samples", "cough.wav")
    if not os.path.exists(sample):
        pytest.skip("cough.wav sample not available")
    result = await _analyze(sample, task="breath")
    assert result["label"] in {"cough", "post-covid symptoms"}
    assert result["confidence"] >= 0.75
    # Raw indicators sanity
    ri = result.get("raw_indicators", {})
    assert "cough_score" in ri and ri["cough_score"] >= 0.4


@pytest.mark.asyncio
async def test_heavy_breath_label_stability():
    """Heavy breathing sample should classify as heavy breathing or post-covid."""
    sample = os.path.join(TEST_DIR, "samples", "heavy_breath.wav")
    if not os.path.exists(sample):
        pytest.skip("heavy_breath.wav sample not available")
    result = await _analyze(sample, task="breath")
    assert result["label"] in {"heavy breathing", "post-covid symptoms"}
    assert result["confidence"] >= 0.7
    # Raw indicators sanity
    ri = result.get("raw_indicators", {})
    assert "onset_rate" in ri and ri["onset_rate"] >= 0.5


@pytest.mark.asyncio
async def test_throat_clearing_indicator_present():
    """If throat clearing sample exists, expect label or high harshness indicator."""
    sample = os.path.join(TEST_DIR, "samples", "throat_clear.wav")
    if not os.path.exists(sample):
        pytest.skip("throat_clear.wav sample not available")
    result = await _analyze(sample, task="breath")
    ri = result.get("raw_indicators", {})
    # Either we label as throat clearing or detect high harshness/onset cues
    ok = (result["label"] == "throat clearing") or (ri.get("harsh_sound_ratio", 0) > 0.3 and 2.0 < ri.get("onset_rate", 0) < 5.0)
    assert ok

