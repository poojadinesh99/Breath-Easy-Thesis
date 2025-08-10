import os
import pandas as pd

try:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    input_path = os.path.join(BASE_DIR, 'datasets/raw/Kaggle-Respiratory/patient_diagnosis.csv')
    output_path = os.path.join(BASE_DIR, 'datasets/raw/Kaggle-Respiratory/patient_diagnosis_with_header.csv')

    print(f"Looking for input file at: {input_path}")
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    df = pd.read_csv(input_path, header=None)
    print("Successfully loaded input CSV.")

    headers = ['patient_id', 'diagnosis']
    df.columns = headers

    df.to_csv(output_path, index=False)
    print(f"Header added and saved to {output_path}")

except Exception as e:
    print(f"Error: {e}")
