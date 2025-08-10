import argparse
import json
import logging
from typing import List, Set, Dict
import pandas as pd

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def extract_labels_from_csv(csv_path: str, diagnosis_columns: List[str]) -> Set[str]:
    """
    Extract unique non-null diagnosis labels from specified columns in a CSV file.
    
    Args:
        csv_path (str): Path to the CSV file.
        diagnosis_columns (List[str]): List of column names containing diagnosis labels.
        
    Returns:
        Set[str]: Set of unique non-null diagnosis labels.
    """
    labels = set()
    
    try:
        # Read the CSV file
        df = pd.read_csv(csv_path)
        logger.info(f"Successfully read {csv_path} with {len(df)} rows")
        
        # Extract labels from each specified column
        for col in diagnosis_columns:
            if col in df.columns:
                # Extract non-null values and add to set
                col_labels = df[col].dropna().unique()
                # Convert to string and strip whitespace
                col_labels = {str(label).strip() for label in col_labels if str(label).strip()}
                labels.update(col_labels)
                logger.info(f"Extracted {len(col_labels)} labels from column '{col}' in {csv_path}")
            else:
                logger.warning(f"Column '{col}' not found in {csv_path}")
                
    except FileNotFoundError:
        logger.error(f"File not found: {csv_path}")
    except pd.errors.EmptyDataError:
        logger.error(f"Empty CSV file: {csv_path}")
    except Exception as e:
        logger.error(f"Error reading {csv_path}: {str(e)}")
        
    return labels

def build_label_map(csv_paths: List[str], diagnosis_columns: List[str]) -> Dict[str, int]:
    """
    Build a label-to-integer ID mapping from multiple CSV files.
    
    Args:
        csv_paths (List[str]): List of CSV file paths.
        diagnosis_columns (List[str]): List of column names containing diagnosis labels.
        
    Returns:
        Dict[str, int]: Label-to-integer ID mapping sorted alphabetically.
    """
    all_labels = set()
    
    # Extract labels from each CSV file
    for csv_path in csv_paths:
        labels = extract_labels_from_csv(csv_path, diagnosis_columns)
        all_labels.update(labels)
        logger.info(f"Total labels so far: {len(all_labels)}")
    
    # Sort labels alphabetically
    sorted_labels = sorted(all_labels)
    
    # Create label-to-ID mapping
    label_map = {label: idx for idx, label in enumerate(sorted_labels)}
    
    logger.info(f"Created label map with {len(label_map)} unique labels")
    return label_map

def save_label_map(label_map: Dict[str, int], output_path: str = 'label_map.json') -> None:
    """
    Save the label map to a JSON file.
    
    Args:
        label_map (Dict[str, int]): Label-to-integer ID mapping.
        output_path (str): Path to save the JSON file.
    """
    try:
        with open(output_path, 'w') as f:
            json.dump(label_map, f, indent=4)
        logger.info(f"Label map saved to {output_path}")
    except Exception as e:
        logger.error(f"Error saving label map to {output_path}: {str(e)}")

def main():
    parser = argparse.ArgumentParser(description="Build a label map from CSV files")
    parser.add_argument('--csvs', nargs='+', required=True, help='Paths to CSV files')
    parser.add_argument('--columns', nargs='+', required=True, help='Diagnosis column names')
    parser.add_argument('--output', default='label_map.json', help='Output JSON file path')
    
    args = parser.parse_args()
    
    # Build the label map
    label_map = build_label_map(args.csvs, args.columns)
    
    # Save the label map
    save_label_map(label_map, args.output)
    
    # Print the label map
    print("Created label map:")
    for label, idx in label_map.items():
        print(f"  {label}: {idx}")

if __name__ == "__main__":
    main()
