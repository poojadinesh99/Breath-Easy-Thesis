import os
import csv
import argparse

def add_wavs_to_csv(wav_dir, csv_path, label="Healthy"): 
    # Get all wav files
    wav_files = [f for f in os.listdir(wav_dir) if f.endswith('.wav')]
    # Prepare rows to add
    new_rows = []
    for wav in wav_files:
        # You can customize columns as needed
        # Example: filename, label
        new_rows.append([wav, label])
    # Append to CSV
    with open(csv_path, 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        for row in new_rows:
            writer.writerow(row)
    print(f"Added {len(new_rows)} rows to {csv_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add VOICED WAVs to training CSV.")
    parser.add_argument('--wav_dir', required=True, help='Directory with new healthy WAV files')
    parser.add_argument('--csv_path', required=True, help='Path to training CSV')
    parser.add_argument('--label', default='Healthy', help='Label to assign (default: Healthy)')
    args = parser.parse_args()
    add_wavs_to_csv(args.wav_dir, args.csv_path, args.label)
