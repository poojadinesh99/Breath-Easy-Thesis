import os
import json
import logging
from datetime import datetime
from sklearn.metrics import classification_report, confusion_matrix, ConfusionMatrixDisplay, balanced_accuracy_score
import numpy as np
import pandas as pd
import joblib
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    ConfusionMatrixDisplay,
)
from joblib import parallel_backend
from sklearn.model_selection import StratifiedKFold, cross_val_score


# IMPORTANT: keep this import exactly like this (you run: python backend/train_model.py)
from backend.archive_librosa.audio_utils import load_kaggle_features_from_annotations

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    # --- Paths (relative to this file) ---
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    AUDIO_DIR = os.path.join(BASE_DIR, "datasets", "raw", "Kaggle-Respiratory")
    REPORTS_DIR = os.path.join(BASE_DIR, "reports")
    MODELS_DIR = os.path.join(BASE_DIR, "saved_models")
    LABEL_MAP_JSON = os.path.join(BASE_DIR, "label_map.json")

    os.makedirs(REPORTS_DIR, exist_ok=True)
    os.makedirs(MODELS_DIR, exist_ok=True)

    # --- Load dataset from Kaggle annotations (.txt -> abnormal/clear) ---
    logger.info("Loading Kaggle Respiratory dataset (annotations -> labels)...")
    X, y, classes = load_kaggle_features_from_annotations(
        audio_dir=AUDIO_DIR,
        feature_type="mfcc",   # try "mel" later for improvement
        duration=5.0,
        normalize=True,
        mode="meanstd",
    )
    if len(X) == 0:
        raise SystemExit("No data loaded. Check Kaggle-Respiratory folder & .txt format.")

    # --- Split ---
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    logger.info(f"Train: {len(X_train)}  Test: {len(X_test)}")

    # --- Train model ---
    clf = RandomForestClassifier(
    n_estimators=500,
    random_state=42,
    class_weight="balanced_subsample",
    n_jobs=1,                  # <= avoid process-based parallelism
    min_samples_leaf=2,
)
    clf.fit(X_train, y_train)

    # --- Evaluate ---
    y_pred = clf.predict(X_test)
    acc = (y_pred == y_test).mean()
    bacc = balanced_accuracy_score(y_test, y_pred)
    report = classification_report(y_test, y_pred, target_names=classes, output_dict=True, zero_division=0)
    logger.info(f"Accuracy: {acc:.4f} | Balanced Acc: {bacc:.4f}")

   # --- Cross-validation  ---
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    with parallel_backend('threading', n_jobs=1):  # <= threads, 1 worker
        cv_scores = cross_val_score(
            clf,
            X, y,                   # full dataset
            cv=cv,
            scoring="balanced_accuracy",
            n_jobs=1,               # IMPORTANT: avoid loky processes
        )
    logger.info(f"CV Balanced Acc: {cv_scores.mean():.4f} ± {cv_scores.std():.4f}")

    # Save classification report (CSV)
    report_df = pd.DataFrame(report).transpose()
    report_csv = os.path.join(REPORTS_DIR, "classification_report.csv")
    report_df.to_csv(report_csv, index=True)
    logger.info(f"Saved report: {report_csv}")

    # Save confusion matrix (PNG)
    cm = confusion_matrix(y_test, y_pred)
    disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=classes)
    plt.figure(figsize=(7, 6))
    disp.plot(cmap=plt.cm.Blues, values_format="d")
    plt.title("Confusion Matrix - RF (MFCC) on Kaggle Respiratory")
    cm_png = os.path.join(REPORTS_DIR, "confusion_matrix.png")
    plt.savefig(cm_png, bbox_inches="tight", dpi=160)
    plt.close()
    logger.info(f"Saved confusion matrix: {cm_png}")
    
    # Save normalized confusion matrix too
    cm = confusion_matrix(y_test, y_pred)
    cm_norm = confusion_matrix(y_test, y_pred, normalize="true")

    disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=classes)
    plt.figure(figsize=(7,6))
    disp.plot(cmap=plt.cm.Blues, values_format="d")
    plt.title("Confusion Matrix - RF (Counts)")
    plt.savefig(os.path.join(REPORTS_DIR, "confusion_matrix_counts.png"), bbox_inches="tight", dpi=160)
    plt.close()

    disp = ConfusionMatrixDisplay(confusion_matrix=cm_norm, display_labels=classes)
    plt.figure(figsize=(7,6))
    disp.plot(cmap=plt.cm.Blues, values_format=".2f")
    plt.title("Confusion Matrix - RF (Normalized)")
    plt.savefig(os.path.join(REPORTS_DIR, "confusion_matrix_normalized.png"), bbox_inches="tight", dpi=160)
    plt.close()

    # --- Save model + label_map ---
    model_path = os.path.join(MODELS_DIR, "model_rf.pkl")
    joblib.dump(clf, model_path)
    logger.info(f"Model saved: {model_path}")

    label_map = {c: i for i, c in enumerate(classes)}  # {"abnormal":0, "clear":1} order matches 'classes'
    with open(LABEL_MAP_JSON, "w") as f:
        json.dump(label_map, f, indent=2)
    logger.info(f"Label map saved: {LABEL_MAP_JSON}")

    # Quick reload sanity check
    clf2 = joblib.load(model_path)
    acc2 = clf2.score(X_test, y_test)
    logger.info(f"Reloaded model accuracy: {acc2:.4f}")

     
if __name__ == "__main__":
    main()
