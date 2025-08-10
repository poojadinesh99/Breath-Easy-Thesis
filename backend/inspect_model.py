import os
import joblib

print("Starting model inspection...")

MODEL_PATH = "model.pkl"

# Check file presence
if not os.path.exists(MODEL_PATH):
    print(" model.pkl not found at expected path.")
    exit()

print("📂 model.pkl found. Attempting to load...")

try:
    model = joblib.load(MODEL_PATH)
    print("Model loaded successfully.")
except Exception as e:
    print(f"Failed to load model: {e}")
    exit()

# Basic details
print(f"Model type: {type(model)}")

# Does it have .predict?
if hasattr(model, "predict"):
    print("Model supports prediction.")
else:
    print(" No predict method found.")

# Classes it predicts
if hasattr(model, "classes_"):
    print(f"Model classes: {model.classes_}")
else:
    print("❔ No .classes_ attribute — might not be a classifier?")

# Feature names
if hasattr(model, "feature_names_in_"):
    print(f" Feature names: {model.feature_names_in_}")
else:
    print("No feature names found.")

# Print internal structure (if not too huge)
print("Model summary:")
print(model)
