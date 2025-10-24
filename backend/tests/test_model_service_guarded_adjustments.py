import numpy as np
import pytest

from backend.app.services.model_service import ModelService


class MockModel:
    def predict_proba(self, X):
        # Start biased towards COPD to simulate prior issue
        base = np.array([0.05, 0.05, 0.05, 0.6, 0.05, 0.05, 0.1, 0.05])
        return np.vstack([base for _ in X])

    def predict(self, X):
        # COPD index in the map below
        return np.array([3 for _ in X])


def build_service():
    svc = ModelService()
    # Provide a deterministic label mapping for tests
    svc.label_map = {str(i): i for i in range(8)}
    svc.inv_label_map = {
        0: "Asthma",
        1: "Bronchiectasis",
        2: "Bronchiolitis",
        3: "COPD",
        4: "Healthy",
        5: "LRTI",
        6: "Pneumonia",
        7: "URTI",
    }
    svc.model = MockModel()
    return svc


def test_normal_breathing_boosts_healthy_and_reduces_copd():
    svc = build_service()

    features = {
        "model_features": np.zeros(120),
        # Values similar to user logs; cough should be below 0.8, normal >= 0.6
        "cough_event_ratio": 0.07,
        "cough_frequency_ratio": 0.105,
        "harsh_sound_ratio": 0.073,
        "onset_rate": 3.6,
        "energy_variation": 1.770,
        "signal_strength": 0.010877,
    }

    # Baseline from mock
    baseline = np.array([0.05, 0.05, 0.05, 0.6, 0.05, 0.05, 0.1, 0.05])
    baseline_copd = baseline[3]
    baseline_healthy = baseline[4]

    res = svc.predict(features)
    probs = res["class_probs"]

    # Healthy should be boosted above baseline; COPD should not increase
    assert probs["Healthy"] > baseline_healthy - 1e-9
    assert probs["COPD"] <= baseline_copd + 1e-9
    assert probs["Healthy"] < baseline_healthy + 1e-9

def test_strong_cough_reduces_healthy_and_redistributes():
    svc = build_service()

    features = {
        "model_features": np.zeros(120),
        # Push cough score high by increasing ratios
        "cough_event_ratio": 0.12,   # above 0.08
        "cough_frequency_ratio": 1.0, # above 0.8
        "harsh_sound_ratio": 0.1,
        "onset_rate": 3.0,
        "energy_variation": 2.0,
        "signal_strength": 0.005,
    }

    baseline = np.array([0.05, 0.05, 0.05, 0.6, 0.05, 0.05, 0.1, 0.05])
    baseline_healthy = baseline[4]

    res = svc.predict(features)
    probs = res["class_probs"]

    # Healthy should decrease from baseline under strong cough
    assert probs["Healthy"] < pytest.approx(baseline_healthy, rel=1e-6)

