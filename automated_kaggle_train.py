import os
import pandas as pd
import numpy as np
import joblib
import json
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report
from backend.app.services.feature_extraction import extract_features

# Load diagnosis mapping
DIAG_CSV = 'backend/data/patient_diagnosis.csv'  # Update path if needed
WAV_DIR = 'backend/data/'  # Update to your actual WAV folder

diag_df = pd.read_csv(DIAG_CSV, header=None, names=['patient_id', 'diagnosis'])
diag_map = dict(zip(diag_df['patient_id'].astype(str), diag_df['diagnosis']))

samples = []
labels = []

print("Extracting features from WAV files...")
for fname in os.listdir(WAV_DIR):
    if fname.endswith('.wav'):
        # Extract patient ID from filename (first 3 digits)
        patient_id = fname.split('_')[0]
        label = diag_map.get(patient_id)
        if label:
            try:
                features = extract_features(os.path.join(WAV_DIR, fname), task_type='breath')
                samples.append(features['model_features'])
                labels.append(label)
            except Exception as e:
                print(f"Error extracting features from {fname}: {e}")

X = np.array(samples)
y = np.array(labels)

# Save dataset for reference
df = pd.DataFrame(X)
df['label'] = y
df.to_csv('respiratory_features.csv', index=False)
print("Saved dataset to respiratory_features.csv")

# Encode labels
le = LabelEncoder()
y_encoded = le.fit_transform(y)

# Train model
clf = RandomForestClassifier(n_estimators=200, max_depth=12, random_state=42, class_weight='balanced')
clf.fit(X, y_encoded)

# Evaluate
y_pred = clf.predict(X)
print(classification_report(y_encoded, y_pred, target_names=le.classes_))

# Save model
joblib.dump(clf, 'backend/ml/models/model_rf.pkl')

# Save label map
label_map = {str(i): label for i, label in enumerate(le.classes_)}
with open('backend/ml/models/label_map.json', 'w') as f:
    json.dump(label_map, f, indent=2)

print("Model and label map saved to backend/ml/models/")
