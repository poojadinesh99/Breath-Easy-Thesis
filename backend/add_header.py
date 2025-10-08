import os
import pandas as pd

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_PATH = os.path.join(BASE_DIR, 'datasets/raw/Kaggle-Respiratory/patient_diagnosis.csv')
OUTPUT_PATH = os.path.join(BASE_DIR, 'datasets/raw/Kaggle-Respiratory/patient_diagnosis_with_header.csv')


def add_header(input_path: str = INPUT_PATH, output_path: str = OUTPUT_PATH):
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")
    df = pd.read_csv(input_path, header=None)
    df.columns = ['patient_id', 'diagnosis']
    df.to_csv(output_path, index=False)
    return output_path


if __name__ == "__main__":
    try:
        out = add_header()
        print(f"Saved: {out}")
    except Exception as e:
        print(f"Error: {e}")
