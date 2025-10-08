#!/usr/bin/env python3
"""Train ML models on OpenSMILE feature CSVs.

Pipeline:
 1. Discover feature CSVs under data/features/<feature_set>/
 2. Derive label from filename (prefix before first underscore by default)
 3. Build / update label_map.json mapping label -> int
 4. Concatenate all features into DataFrame X, labels y
 5. Train with StandardScaler + PCA(<=100) + model (RF & SVM via GridSearchCV)
 6. Pick best by mean cross‑val F1 (macro) and evaluate on hold‑out test set
 7. Save best pipeline to backend/ml/models/model_opensmile.pkl
 8. Write classification_report.csv and confusion_matrix.png to backend/reports/

Non‑destructive: creates needed folders. If not enough data or labels, exits with message.

Usage examples:
  python backend/ml/training/train_opensmile_rf.py --feature_set egemaps
  python backend/ml/training/train_opensmile_rf.py --feature_set compare_2016 --pca 150

Assumptions:
  - Feature CSV filenames correspond to original audio filenames (without .wav)
  - Label can be inferred as substring before first '_' OR full stem if using --label_strategy=stem
  - label_map.json will be (re)written to reflect encountered labels (sorted alphabetically unless --preserve_label_map)

"""
from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import List, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.decomposition import PCA
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC

# Remove always-on merge_to_coarse; replace with optional system

def load_external_coarse_map(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        if path.suffix.lower() == ".json":
            with open(path, "r") as f:
                data = json.load(f)
            if isinstance(data, dict):
                return {str(k).lower(): str(v).lower() for k, v in data.items()}
        elif path.suffix.lower() == ".csv":
            df = pd.read_csv(path)
            cols = [c.lower() for c in df.columns]
            if len(cols) >= 2:
                ocol = df.columns[0]
                ccol = df.columns[1]
                return {str(r[ocol]).lower(): str(r[ccol]).lower() for _, r in df.iterrows()}
    except Exception as e:
        print(f"[WARN] Failed to load coarse_map {path}: {e}")
    return {}

COARSE_CATEGORIES = ["normal", "wheeze", "crackle", "combined", "other"]

def heuristic_coarse_from_filename(orig_label: str, file_stem: str) -> str:
    l = orig_label.lower()
    stem = file_stem.lower()
    # Normalize separators to spaces then split
    tokens = [t for t in re.split(r"[^a-zA-Z]+", stem) if t]
    tokset = set(tokens)
    # explicit word tokens
    has_wheeze = any(t in {"wheeze", "wheez", "w"} for t in tokset)
    has_crackle = any(t in {"crackle", "crackles", "crackl", "c"} for t in tokset)
    has_normal = any(t in {"normal", "healthy", "control", "baseline", "n"} for t in tokset)
    # disease condition proxies (approx)
    if any(t in tokset for t in {"asthma", "copd", "urti"}):
        has_wheeze = True
    if any(t in tokset for t in {"pneumonia", "fibrosis", "lungfibrosis"}):
        has_crackle = True
    if any(t in tokset for t in {"bronchiectasis"}):
        has_wheeze = True; has_crackle = True

    if has_wheeze and has_crackle:
        return "combined"
    if has_wheeze:
        return "wheeze"
    if has_crackle:
        return "crackle"
    if has_normal:
        return "normal"
    return "other"

# ----------------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------------
THIS_FILE = Path(__file__).resolve()
BACKEND_ROOT = THIS_FILE.parents[2]  # backend/
DEFAULT_FEATURE_DIR = BACKEND_ROOT / "data" / "features"  # data/features/<feature_set>/
DEFAULT_LABEL_MAP = BACKEND_ROOT / "label_map.json"
MODELS_DIR = BACKEND_ROOT / "ml" / "models"
REPORTS_DIR = BACKEND_ROOT / "reports"

MODELS_DIR.mkdir(parents=True, exist_ok=True)
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

# ----------------------------------------------------------------------------------
# Arg Parsing
# ----------------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="Train OpenSMILE ML models (RF + SVM)")
    p.add_argument("--feature_set", default="egemaps", help="Feature set directory name under data/features")
    p.add_argument("--features_dir", default=str(DEFAULT_FEATURE_DIR), help="Root features directory")
    p.add_argument("--label_map", default=str(DEFAULT_LABEL_MAP), help="Path to label_map.json")
    p.add_argument("--label_strategy", choices=["prefix", "stem"], default="prefix", help="How to derive label from filename")
    p.add_argument("--test_size", type=float, default=0.2, help="Test split proportion")
    p.add_argument("--random_state", type=int, default=42)
    p.add_argument("--pca", type=int, default=100, help="Max PCA components (auto reduced if > n_features or n_samples-1)")
    p.add_argument("--n_jobs", type=int, default=-1, help="Parallel jobs for GridSearchCV")
    p.add_argument("--preserve_label_map", action="store_true", help="Keep existing label_map.json mapping if all labels covered")
    p.add_argument("--min_files", type=int, default=10, help="Minimum number of files required to attempt training")
    p.add_argument("--drop_singletons", action="store_true", help="Drop classes with only 1 sample before splitting")
    # NEW optional coarse merging controls
    p.add_argument("--merge_coarse", action="store_true", help="Merge raw labels into coarse respiratory categories")
    p.add_argument("--coarse_map", type=str, default="", help="Optional path to JSON or CSV mapping original->coarse")
    return p.parse_args()

# ----------------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------------

def derive_label(stem: str, strategy: str) -> str:
    if strategy == "stem":
        return stem.lower()
    # prefix strategy: take portion before first underscore
    return stem.split("_")[0].lower()


def load_or_init_label_map(path: Path) -> dict:
    if path.exists():
        try:
            with open(path, "r") as f:
                data = json.load(f)
            if isinstance(data, dict):
                return data
        except Exception:
            pass
    return {}


def build_label_map(labels: List[str], existing: dict, preserve: bool) -> dict:
    uniq = sorted(set(labels))
    if preserve and existing and all(l in existing for l in uniq):
        return existing
    # fresh mapping alphabetical order
    return {lab: i for i, lab in enumerate(uniq)}


def read_feature_csvs(feature_dir: Path, label_strategy: str) -> Tuple[pd.DataFrame, List[str]]:
    csv_files = sorted(feature_dir.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"No feature CSVs found in {feature_dir}")
    rows = []
    labels = []
    for fp in csv_files:
        try:
            df = pd.read_csv(fp)
            if df.empty:
                continue
            # Expect single row per file from batch extraction script
            row = df.iloc[0].to_dict()
            label = derive_label(fp.stem, label_strategy)
            row["__label"] = label
            row["__file"] = fp.name
            rows.append(row)
            labels.append(label)
        except Exception as e:
            print(f"[WARN] Failed to read {fp}: {e}")
    if not rows:
        raise RuntimeError(f"No valid feature rows parsed in {feature_dir}")
    full_df = pd.DataFrame(rows)
    return full_df, labels


def ensure_numeric(df: pd.DataFrame) -> pd.DataFrame:
    # Keep only numeric columns (exclude meta columns)
    meta_cols = {"__label", "__file", "__orig_label"}  # added __orig_label
    num_df = df.drop(columns=[c for c in df.columns if c in meta_cols], errors="ignore")
    for c in num_df.columns:
        num_df[c] = pd.to_numeric(num_df[c], errors="coerce")
    num_df = num_df.fillna(0.0)
    return num_df

# NEW: merge fine/raw label into coarse respiratory categories
def merge_to_coarse(label: str) -> str:
    """Map raw dataset label (filename prefix) into coarse respiratory category.

    Rules (heuristic, can be refined):
      - normal / healthy / control / baseline => normal
      - asthma, copd, urti => wheeze (typically wheeze‑dominant conditions)
      - pneumonia, lung_fibrosis / fibrosis => crackle (crackle‑dominant)
      - bronchiectasis => combined (often presents with both wheeze + crackles)
      - explicit tokens 'wheeze', 'crackle' preserved if present
      - if both wheeze and crackle indicators found => combined
      - otherwise => other
    """
    l = label.lower()
    norm = ''.join(ch for ch in l if ch.isalnum())  # remove separators

    # Direct keyword detection
    has_wheeze_kw = 'wheeze' in l
    has_crackle_kw = 'crackle' in l or 'crackl' in l

    # Disease group sets
    wheeze_set = {"asthma", "copd", "urti"}
    crackle_set = {"pneumonia", "lungfibrosis", "fibrosis"}
    combined_set = {"bronchiectasis"}

    in_wheeze = has_wheeze_kw or any(tok in norm for tok in wheeze_set)
    in_crackle = has_crackle_kw or any(tok in norm for tok in crackle_set)
    in_combined = any(tok in norm for tok in combined_set)

    if any(tok in norm for tok in ["normal", "healthy", "control", "baseline"]):
        return "normal"

    # Combined overrides (explicit bronchiectasis or both signals)
    if in_combined or (in_wheeze and in_crackle):
        return "combined"
    if in_wheeze:
        return "wheeze"
    if in_crackle:
        return "crackle"

    return "other"

# ----------------------------------------------------------------------------------
# Main Training Logic
# ----------------------------------------------------------------------------------

def main():
    args = parse_args()

    feature_dir = Path(args.features_dir) / args.feature_set
    if not feature_dir.exists():
        print(f"Feature directory does not exist: {feature_dir}")
        return 2

    # Load data
    try:
        df, labels_raw = read_feature_csvs(feature_dir, args.label_strategy)
    except Exception as e:
        print(f"Error loading features: {e}")
        return 2

    # OPTIONAL coarse merging
    if args.merge_coarse:
        df["__orig_label"] = df["__label"].astype(str)
        # external map
        cmap = load_external_coarse_map(Path(args.coarse_map)) if args.coarse_map else {}
        if cmap:
            print(f"Loaded external coarse map with {len(cmap)} entries")
        coarse_labels = []
        for _, row in df.iterrows():
            orig = row["__orig_label"].lower()
            file_stem = Path(row["__file"]).stem
            if orig in cmap:
                coarse = cmap[orig]
            else:
                coarse = heuristic_coarse_from_filename(orig, file_stem)
            if coarse not in COARSE_CATEGORIES:
                coarse = "other"
            coarse_labels.append(coarse)
        df["__label"] = coarse_labels
        labels_raw = coarse_labels
        dist = pd.Series(coarse_labels).value_counts().to_dict()
        print("Coarse label distribution:", dist)
        if len(set(coarse_labels)) < 2:
            print("[WARN] Coarse mapping produced a single class. Reverting to original labels. Provide a mapping via --coarse_map if needed.")
            df["__label"] = df["__orig_label"]
            labels_raw = df["__label"].tolist()
    else:
        # ensure __orig_label exists for consistency
        df["__orig_label"] = df["__label"]

    if len(df) < args.min_files:
        print(f"Not enough samples ({len(df)}) to train. Need at least {args.min_files}.")
        return 2

    # Build / update label map
    label_map_path = Path(args.label_map)
    existing_map = load_or_init_label_map(label_map_path)
    label_map = build_label_map(labels_raw, existing_map, args.preserve_label_map)

    # Filter to only samples whose label is in mapping
    df = df[df["__label"].isin(label_map.keys())].reset_index(drop=True)
    if df["__label"].nunique() < 2:
        print("Need at least two classes for training.")
        return 2

    y = df["__label"].map(label_map).astype(int).to_numpy()
    X = ensure_numeric(df)
    feature_names = X.columns.tolist()
    X = X.to_numpy(dtype=float)

    # Class distribution analysis
    import collections
    label_counts = collections.Counter(y)
    singleton_labels = [lab for lab, cnt in label_counts.items() if cnt == 1]
    if singleton_labels and args.drop_singletons:
        keep_mask = ~np.isin(y, singleton_labels)
        X = X[keep_mask]
        y = y[keep_mask]
        print(f"Dropped singleton classes (samples<2): {[int(l) for l in singleton_labels]}")
        label_counts = collections.Counter(y)

    if len(set(y)) < 2:
        print("After processing, only one class remains. Cannot train.")
        return 2

    can_stratify = all(cnt >= 2 for cnt in label_counts.values())
    if not can_stratify:
        print("Warning: Some classes have only 1 sample; falling back to non-stratified split.")

    # Train/test split (fallback if stratify impossible)
    stratify_arg = y if can_stratify else None
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=args.test_size, random_state=args.random_state, stratify=stratify_arg
    )

    # Determine PCA components (cannot exceed min(n_features, n_samples-1))
    max_pca = min(args.pca, X_train.shape[1], max(1, X_train.shape[0] - 1))

    # Pipelines
    base_steps = [("scaler", StandardScaler()), ("pca", PCA(n_components=max_pca, random_state=args.random_state))]

    rf = Pipeline(base_steps + [("clf", RandomForestClassifier(random_state=args.random_state))])
    svm = Pipeline(base_steps + [("clf", SVC(probability=True, random_state=args.random_state))])

    rf_grid = {
        "clf__n_estimators": [100, 300],
        "clf__max_depth": [None, 10, 20],
        "clf__min_samples_split": [2, 5],
    }
    svm_grid = {
        "clf__C": [0.1, 1, 10],
        "clf__kernel": ["rbf", "linear"],
        "clf__gamma": ["scale", "auto"],
    }

    cv = StratifiedKFold(n_splits=3, shuffle=True, random_state=args.random_state)

    print("Running GridSearch for RandomForest ...")
    rf_search = GridSearchCV(
        rf,
        rf_grid,
        scoring="f1_macro",
        cv=cv,
        n_jobs=args.n_jobs,
        verbose=1,
        refit=True,
    )
    rf_search.fit(X_train, y_train)
    print(f"RF best F1={rf_search.best_score_:.4f} params={rf_search.best_params_}")

    print("Running GridSearch for SVM ...")
    svm_search = GridSearchCV(
        svm,
        svm_grid,
        scoring="f1_macro",
        cv=cv,
        n_jobs=args.n_jobs,
        verbose=1,
        refit=True,
    )
    svm_search.fit(X_train, y_train)
    print(f"SVM best F1={svm_search.best_score_:.4f} params={svm_search.best_params_}")

    # Select best model
    if rf_search.best_score_ >= svm_search.best_score_:
        best_search = rf_search
        model_name = "RandomForest"
    else:
        best_search = svm_search
        model_name = "SVM"

    best_pipeline = best_search.best_estimator_
    print(f"Selected model: {model_name} (CV F1={best_search.best_score_:.4f})")

    # Evaluate on test set
    y_pred = best_pipeline.predict(X_test)
    test_f1 = f1_score(y_test, y_pred, average="macro")
    print(f"Test macro F1: {test_f1:.4f}")

    # ACTIVE LABELS (those actually present in test/pred) to avoid mismatch errors
    active_indices = sorted(set(y_test) | set(y_pred))
    active_items = [
        (lab, idx) for lab, idx in sorted(label_map.items(), key=lambda x: x[1]) if idx in active_indices
    ]

    # Classification report restricted to active labels
    cls_report_dict = classification_report(
        y_test,
        y_pred,
        labels=[idx for _, idx in active_items],
        target_names=[lab for lab, _ in active_items],
        output_dict=True,
        zero_division=0,
    )
    cls_report_df = pd.DataFrame(cls_report_dict).T
    cls_report_csv = REPORTS_DIR / "classification_report.csv"
    cls_report_df.to_csv(cls_report_csv, index=True)
    print(f"Wrote {cls_report_csv}")

    # NEW: per-class metrics (precision, recall, f1, support)
    per_class_rows = []
    for lab, idx in active_items:
        if lab in cls_report_dict:
            stats = cls_report_dict[lab]
            per_class_rows.append({
                "label": lab,
                "index": idx,
                "precision": stats.get("precision", 0.0),
                "recall": stats.get("recall", 0.0),
                "f1": stats.get("f1-score", 0.0),
                "support": stats.get("support", 0),
            })
    if per_class_rows:
        per_class_df = pd.DataFrame(per_class_rows).sort_values("index")
        per_class_path = REPORTS_DIR / "metrics_per_class.csv"
        per_class_df.to_csv(per_class_path, index=False)
        print(f"Wrote {per_class_path}")

    # Confusion matrices (raw & normalized, active labels only)
    cm = confusion_matrix(y_test, y_pred, labels=[idx for _, idx in active_items])
    # safe row-normalization
    with np.errstate(divide='ignore', invalid='ignore'):
        row_sums = cm.sum(axis=1, keepdims=True)
        cm_norm = np.divide(cm, row_sums, where=row_sums != 0)
        cm_norm[np.isnan(cm_norm)] = 0.0

    # Save raw / normalized matrices as CSV
    raw_cm_csv = REPORTS_DIR / "confusion_matrix_raw.csv"
    norm_cm_csv = REPORTS_DIR / "confusion_matrix_normalized.csv"
    pd.DataFrame(cm, index=[lab for lab, _ in active_items], columns=[lab for lab, _ in active_items]).to_csv(raw_cm_csv)
    pd.DataFrame(cm_norm, index=[lab for lab, _ in active_items], columns=[lab for lab, _ in active_items]).to_csv(norm_cm_csv)
    print(f"Wrote {raw_cm_csv}")
    print(f"Wrote {norm_cm_csv}")

    # Plot raw matrix
    try:
        import matplotlib.pyplot as plt
        import seaborn as sns  # optional
        has_sns = True
    except Exception:
        import matplotlib.pyplot as plt
        has_sns = False

    def _plot_and_save(matrix, labels_txt, title, out_path, fmt_str, cmap="Blues"):
        fig, ax = plt.subplots(figsize=(4, 4))
        if has_sns:
            import seaborn as sns  # type: ignore
            sns.heatmap(matrix, annot=True, fmt=fmt_str, cmap=cmap, cbar=False, ax=ax)
        else:
            ax.imshow(matrix, cmap=cmap)
            for (i, j), v in np.ndenumerate(matrix):
                ax.text(j, i, (fmt_str % v) if fmt_str != 'd' else str(v), ha="center", va="center")
        ax.set_xlabel("Predicted")
        ax.set_ylabel("True")
        ax.set_xticks(range(len(labels_txt)))
        ax.set_yticks(range(len(labels_txt)))
        ax.set_xticklabels(labels_txt, rotation=45, ha="right")
        ax.set_yticklabels(labels_txt)
        ax.set_title(title)
        fig.tight_layout()
        fig.savefig(out_path, dpi=150)
        plt.close(fig)
        print(f"Wrote {out_path}")

    class_labels = [lab for lab, _ in active_items]
    _plot_and_save(cm, class_labels, "Confusion Matrix (Raw)", REPORTS_DIR / "confusion_matrix_raw.png", 'd')
    _plot_and_save(cm_norm, class_labels, "Confusion Matrix (Normalized)", REPORTS_DIR / "confusion_matrix_normalized.png", '.2f')

    # (Backward compatibility) keep old filename pointing to raw matrix
    if not (REPORTS_DIR / "confusion_matrix.png").exists():
        (REPORTS_DIR / "confusion_matrix_raw.png").rename(REPORTS_DIR / "confusion_matrix.png")

    # Save / update label map
    with open(label_map_path, "w") as f:
        json.dump(label_map, f, indent=2)
    print(f"Updated label map: {label_map_path}")

    # ALSO save label_map inside models directory for portability
    models_label_map_path = MODELS_DIR / "label_map.json"
    with open(models_label_map_path, "w") as f:
        json.dump(label_map, f, indent=2)
    print(f"Copied label map to {models_label_map_path}")

    # Save model pipeline (pipeline only so FastAPI can load and call predict())
    model_path = MODELS_DIR / "model_opensmile.pkl"
    joblib.dump(best_pipeline, model_path)
    print(f"Saved model pipeline to {model_path}")

    # Save metadata separately for inspection
    meta = {
        "feature_names": feature_names,
        "label_map": label_map,
        "feature_set": args.feature_set,
        "pca_components": max_pca,
        "model_type": model_name,
        "cv_best_params": best_search.best_params_,
        "cv_best_score": best_search.best_score_,
        "test_f1_macro": test_f1,
    }
    meta_path = MODELS_DIR / "model_opensmile_meta.json"
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2)
    print(f"Saved metadata to {meta_path}")

    print("Done.")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
