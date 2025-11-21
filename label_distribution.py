import pandas as pd
from collections import Counter

df = pd.read_csv("backend/data/patient_diagnosis.csv", header=None)
labels = df.iloc[:, 1]  # Assuming second column is the label
print("Label distribution:", Counter(labels))