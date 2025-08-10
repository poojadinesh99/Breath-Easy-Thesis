import os
import numpy as np
import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
from utils.audio_utils import load_all_audio_features_and_labels

# Adjust paths as needed
AUDIO_DIR = "datasets/raw/Kaggle-Respiratory"
LABEL_MAP_PATH = "label_map.json"
# Load data
print("Loading dataset from Coswara + Kaggle...")
X, y = load_all_audio_features_and_labels(
    audio_dir=AUDIO_DIR,
    label_map_path=LABEL_MAP_PATH,
    feature_type='mfcc',  # or 'mel'
    duration=5.0  # seconds
)


# Check shape
print(f"Loaded {len(X)} samples with {X.shape[1]} features.")
print("Loaded samples:", len(X))
print("Feature shape:", X[0].shape if len(X) > 0 else "No features loaded")
print("Labels:", set(y))
# Split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train
print(" Training Random Forest Classifier...")
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

# Evaluate
y_pred = clf.predict(X_test)
print("Classification Report:")
print(classification_report(y_test, y_pred))

# Save model
model_path = os.path.join("saved_models", "model.pkl")
os.makedirs(os.path.dirname(model_path), exist_ok=True)
joblib.dump(clf, model_path)
print(f"Model saved to {model_path}")
