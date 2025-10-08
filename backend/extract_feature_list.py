#!/usr/bin/env python3
"""Extract feature list from OpenSMILE CSV files.

This script reads the first CSV file from data/features/egemaps/ 
and extracts the column names (feature names) to save as feature_list.json.
This ensures consistent feature ordering during inference.
"""

import json
import pandas as pd
from pathlib import Path

def main():
    # Define paths
    backend_dir = Path(__file__).parent
    features_dir = backend_dir / "data" / "features" / "egemaps"
    output_file = backend_dir / "feature_list.json"
    
    # Check if features directory exists
    if not features_dir.exists():
        print(f"Error: Features directory not found: {features_dir}")
        print("Run batch feature extraction first:")
        print("python backend/scripts/extract_features_batch.py --feature_set egemaps")
        return 1
    
    # Find first CSV file
    csv_files = list(features_dir.glob("*.csv"))
    if not csv_files:
        print(f"Error: No CSV files found in {features_dir}")
        return 1
    
    # Read first CSV file
    first_csv = csv_files[0]
    print(f"Reading feature names from: {first_csv}")
    
    try:
        df = pd.read_csv(first_csv)
        if df.empty:
            print(f"Error: CSV file is empty: {first_csv}")
            return 1
        
        # Extract column names (feature names)
        feature_names = df.columns.tolist()
        
        # Save to JSON
        with open(output_file, 'w') as f:
            json.dump(feature_names, f, indent=2)
        
        print(f"Saved {len(feature_names)} features to feature_list.json")
        print(f"First 5 features: {feature_names[:5]}")
        
        return 0
        
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        return 1

if __name__ == "__main__":
    exit(main())
