import argparse
import json
import logging
from typing import List, Set, Dict
import pandas as pd

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def extract_labels_from_csv(csv_path: str, diagnosis_columns: List[str]) -> Set[str]:
    labels = set()
    try:
        df = pd.read_csv(csv_path)
        logger.info(f"Read {csv_path} rows={len(df)}")
        for col in diagnosis_columns:
            if col in df.columns:
                col_labels = {str(v).strip() for v in df[col].dropna().unique() if str(v).strip()}
                labels.update(col_labels)
            else:
                logger.warning(f"Missing column {col} in {csv_path}")
    except FileNotFoundError:
        logger.error(f"File not found: {csv_path}")
    except pd.errors.EmptyDataError:
        logger.error(f"Empty CSV file: {csv_path}")
    except Exception as e:
        logger.error(f"Error reading {csv_path}: {e}")
    return labels


def build_label_map(csv_paths: List[str], diagnosis_columns: List[str]) -> Dict[str, int]:
    all_labels = set()
    for p in csv_paths:
        all_labels.update(extract_labels_from_csv(p, diagnosis_columns))
    sorted_labels = sorted(all_labels)
    label_map = {label: idx for idx, label in enumerate(sorted_labels)}
    logger.info(f"Label map size={len(label_map)} labels={sorted_labels}")
    return label_map


def save_label_map(label_map: Dict[str, int], output_path: str = 'label_map.json') -> None:
    try:
        with open(output_path, 'w') as f:
            json.dump(label_map, f, indent=4)
        logger.info(f"Saved label map -> {output_path}")
    except Exception as e:
        logger.error(f"Error saving label map {output_path}: {e}")


def main():
    parser = argparse.ArgumentParser(description="Build a label map from CSV files")
    parser.add_argument('--csvs', nargs='+', required=True, help='Paths to CSV files')
    parser.add_argument('--columns', nargs='+', required=True, help='Diagnosis column names')
    parser.add_argument('--output', default='label_map.json', help='Output JSON file path')
    args = parser.parse_args()

    label_map = build_label_map(args.csvs, args.columns)
    save_label_map(label_map, args.output)
    for label, idx in label_map.items():
        print(f"{idx}\t{label}")


if __name__ == "__main__":
    main()
