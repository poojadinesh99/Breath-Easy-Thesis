import csv
import argparse

# This script removes any row in the CSV with more than 2 columns

def clean_csv(input_csv, output_csv):
    cleaned = []
    with open(input_csv, 'r') as infile:
        reader = csv.reader(infile)
        for row in reader:
            if len(row) == 2:
                cleaned.append(row)
            elif len(row) > 2:
                # Keep only the last two columns (filename, diagnosis)
                cleaned.append(row[-2:])
    with open(output_csv, 'w', newline='') as outfile:
        writer = csv.writer(outfile)
        writer.writerows(cleaned)
    print(f"Cleaned CSV written to {output_csv} ({len(cleaned)} rows)")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Clean patient_diagnosis.csv to ensure only 2 columns per row.")
    parser.add_argument('--input_csv', required=True, help='Path to input CSV')
    parser.add_argument('--output_csv', required=True, help='Path to output cleaned CSV')
    args = parser.parse_args()
    clean_csv(args.input_csv, args.output_csv)
