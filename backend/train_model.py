import numpy as np
from sklearn.ensemble import RandomForestClassifier
import joblib
import os
#  Mock training data (like MFCC/logMel vectors)
X = np.random.rand(100, 39)  # 39 features (13 MFCC + 26 logMel)
y = np.random.randint(0, 2, 100)  # Binary classes (e.g. normal vs anomaly)

model = RandomForestClassifier()
model.fit(X, y)

print("Saving the trained model...",os.getcwd())
joblib.dump(model, "model.pkl")
print("Model trained and saved as model.pkl")