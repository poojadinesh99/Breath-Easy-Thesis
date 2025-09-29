import numpy as np
import pandas as pd
from typing import Literal, Optional, Tuple
import json
import os
try:
    import opensmile
except ImportError as e:
    raise ImportError(
        "opensmile package not installed. Add 'opensmile' to requirements and pip install it."
    ) from e
# Load expected feature list at module import
FEATURE_LIST_PATH = os.path.join(os.path.dirname(__file__), "feature_list.json")
with open(FEATURE_LIST_PATH) as f:
    EXPECTED_FEATURES = json.load(f)

FeatureSetName = Literal["eGeMAPS", "ComParE_2016"]
FeatureLevelName = Literal["func", "lld"]
AggregateName = Literal["none", "mean", "std", "meanstd", "median"]


def _resolve_feature_set(name: FeatureSetName):
    key = str(name).lower()
    if key == "egemaps":
        return opensmile.FeatureSet.eGeMAPSv02
    if key in ("compare_2016", "compare", "compare2016"):
        return opensmile.FeatureSet.ComParE_2016
    # default
    return opensmile.FeatureSet.eGeMAPSv02


def _resolve_feature_level(name: FeatureLevelName):
    key = str(name).lower()
    if key in ("func", "functional", "functionals"):
        return opensmile.FeatureLevel.Functionals
    return opensmile.FeatureLevel.LowLevelDescriptors


def _aggregate_dataframe(df: pd.DataFrame, how: AggregateName) -> pd.Series:
    """Aggregate a time-indexed feature DataFrame into a single row Series."""
    if how == "none":
        # Return first row if present
        return df.iloc[0]
    if how == "mean":
        return df.mean(axis=0, numeric_only=True)
    if how == "std":
        return df.std(axis=0, numeric_only=True)
    if how == "median":
        return df.median(axis=0, numeric_only=True)
    if how == "meanstd":
        mu = df.mean(axis=0, numeric_only=True)
        sd = df.std(axis=0, numeric_only=True).fillna(0.0)
        # concatenate as [mean..., std...]
        mu.index = [f"{c}__mean" for c in mu.index]
        sd.index = [f"{c}__std" for c in sd.index]
        return pd.concat([mu, sd])
    raise ValueError(f"Unknown aggregation: {how}")


def extract_opensmile_dataframe(
    audio_path: str,
    feature_set: FeatureSetName = "eGeMAPS",
    feature_level: FeatureLevelName = "func",
) -> pd.DataFrame:
    """
    Run OpenSMILE on an audio file and return a pandas DataFrame.
    - For Functionals level, the result is typically a single-row DataFrame.
    - For LLD level, the result has many rows (time frames).
    """
    sm = opensmile.Smile(
        feature_set=_resolve_feature_set(feature_set),
        feature_level=_resolve_feature_level(feature_level),
    )
    return sm.process_file(audio_path)


def dataframe_to_vector(
    df: pd.DataFrame,
    feature_level: FeatureLevelName = "func",
    aggregate_if_lld: AggregateName = "meanstd",
) -> Tuple[np.ndarray, Optional[pd.Index]]:
    """
    Convert an OpenSMILE output DataFrame to a 1D numeric vector.
    - If feature_level == 'func': use the single row as-is.
    - If 'lld': aggregate across rows with the chosen strategy (default mean+std).
    Returns (vector, column_index)
    """
    if df is None or df.empty:
        raise ValueError("Empty OpenSMILE features DataFrame")

    # Flatten MultiIndex columns if present
    if isinstance(df.columns, pd.MultiIndex):
        df = df.copy()
        df.columns = ["_".join([str(x) for x in tup if str(x) != ""]) for tup in df.columns.values]

    if feature_level == "func":
        row = df.iloc[0]
    else:
        row = _aggregate_dataframe(df, aggregate_if_lld)

    vec = row.to_numpy(dtype=float)
    # Safety: replace NaNs/Infs
    vec = np.nan_to_num(vec, nan=0.0, posinf=0.0, neginf=0.0)
    return vec, row.index


def extract_features_for_inference(
    audio_path: str,
    feature_set: FeatureSetName = "eGeMAPS",
    feature_level: FeatureLevelName = "func",
    aggregate_if_lld: AggregateName = "meanstd",
) -> np.ndarray:
    """
    Full pipeline to return a (1, N) numpy array for sklearn.
    Enforces alignment with feature_list.json.
    """
    df = extract_opensmile_dataframe(audio_path, feature_set=feature_set, feature_level=feature_level)
    vec, cols = dataframe_to_vector(df, feature_level=feature_level, aggregate_if_lld=aggregate_if_lld)

    # Convert back to DataFrame to align columns
    aligned_df = pd.DataFrame([vec], columns=cols)

    # Ensure all expected features are present and ordered
    missing = [col for col in EXPECTED_FEATURES if col not in aligned_df.columns]
    if missing:
        raise ValueError(f"Missing expected features: {missing}")

    aligned_vec = aligned_df[EXPECTED_FEATURES].to_numpy(dtype=float)

    return aligned_vec  # shape: (1, N)
