#!/usr/bin/env python3
"""
Feature Importance Dumper for RandomForestClassifier
----------------------------------------------------
Loads model_rf.pkl (from backend/ml/models/) and prints:
- JSON {feature_name: importance} sorted descending
- Mean importance
- Top 10 features
"""

import json
import os
import sys
import pickle
from pathlib import Path


def build_feature_names() -> list:
    names = []
    # MFCC means and stds (20 + 20)
    names += [f"MFCC_mean_{i+1}" for i in range(20)]
    names += [f"MFCC_std_{i+1}" for i in range(20)]
    # Chroma means and stds (12 + 12)
    names += [f"Chroma_mean_{i+1}" for i in range(12)]
    names += [f"Chroma_std_{i+1}" for i in range(12)]
    # Spectral contrast means and stds (7 + 7)
    names += [f"SpecContrast_mean_{i+1}" for i in range(7)]
    names += [f"SpecContrast_std_{i+1}" for i in range(7)]
    # Tonnetz means and stds (6 + 6)
    names += [f"Tonnetz_mean_{i+1}" for i in range(6)]
    names += [f"Tonnetz_std_{i+1}" for i in range(6)]
    # Aggregate scalars
    names += ["SpecCentroid_mean", "SpecBandwidth_mean", "SpecRolloff_mean"]
    names += ["Tempo", "OnsetStrength_mean"]
    # Delta MFCC means (20)
    names += [f"DeltaMFCC_mean_{i+1}" for i in range(20)]
    # RMS/ZCR stats (3)
    names += ["RMS_var", "RMS_mean", "ZCR_mean"]

    # Pad or truncate to 120
    while len(names) < 120:
        names.append(f"ExtraFeature_{len(names)+1}")
    return names[:120]


def find_model_path() -> Path:
    candidates = [
        Path("backend/ml/models/model_rf.pkl"),
        Path("ml/models/model_rf.pkl"),
        Path("model_rf.pkl"),
    ]
    for p in candidates:
        if p.exists():
            return p
    # fallback recursive search
    for p in Path(".").rglob("model_rf.pkl"):
        return p
    raise FileNotFoundError("Could not locate model_rf.pkl anywhere in project.")


def try_joblib_load(path: Path):
    try:
        import joblib
        return joblib.load(path)
    except Exception:
        return None


def try_pickle_load(path: Path):
    with open(path, "rb") as f:
        return pickle.load(f)


def extract_estimator(obj):
    """Recursively locate estimator exposing feature_importances_."""
    if hasattr(obj, "feature_importances_"):
        return obj

    for attr in ("named_steps", "steps"):
        if hasattr(obj, attr):
            steps = getattr(obj, attr)
            iterable = steps.values() if isinstance(steps, dict) else [s for _, s in steps]
            for step in iterable:
                est = extract_estimator(step)
                if est is not None:
                    return est

    if isinstance(obj, dict):
        for v in obj.values():
            est = extract_estimator(v)
            if est is not None:
                return est
    if isinstance(obj, (list, tuple)):
        for v in obj:
            est = extract_estimator(v)
            if est is not None:
                return est

    for attr in ("estimator_", "best_estimator_", "model", "classifier", "clf"):
        if hasattr(obj, attr):
            est = extract_estimator(getattr(obj, attr))
            if est is not None:
                return est
    return None


def main():
    model_path = find_model_path()
    feature_names = build_feature_names()

    obj = try_joblib_load(model_path)
    if obj is None:
        try:
            obj = try_pickle_load(model_path)
        except Exception as e:
            print(f"ERROR: failed to load model: {e}", file=sys.stderr)
            sys.exit(2)

    est = extract_estimator(obj)
    if est is None or not hasattr(est, "feature_importances_"):
        print("ERROR: No estimator with feature_importances_ found", file=sys.stderr)
        sys.exit(3)

    importances = list(map(float, est.feature_importances_))
    # Align with feature names
    if len(importances) != len(feature_names):
        importances = (importances + [0.0] * 120)[:120]

    pairs = sorted(zip(feature_names, importances), key=lambda x: x[1], reverse=True)

    # Print JSON
    mapping_sorted = {n: i for n, i in pairs}
    print(json.dumps(mapping_sorted, indent=2))

    mean_imp = sum(importances) / len(importances)
    print(f"\nMean importance: {mean_imp:.6f}")
    print("Top 10 features:")
    for n, i in pairs[:10]:
        print(f"- {n}: {i:.6f}")


if __name__ == "__main__":
    main()
