#!/usr/bin/env python3
"""Batch OpenSMILE feature extraction.

Scans a directory of audio files (.wav) and writes per-file feature CSVs to
  data/features/<feature_set>/ (or custom output root in future).

Example:
  python backend/scripts/extract_features_batch.py --feature_set egemaps
  python backend/scripts/extract_features_batch.py --feature_set compare_2016 --level lld --aggregate meanstd
  python backend/scripts/extract_features_batch.py --input_dir datasets/raw/Kaggle-Respiratory --feature_set egemaps

Feature set options map to opensmile enums:
  egemaps -> eGeMAPSv02
  compare_2016 / compare -> ComParE_2016

Exits non‑zero if any fatal error occurs.
"""
from __future__ import annotations

import argparse
import sys
import os
from pathlib import Path
import pandas as pd

# Local imports
sys.path.append(str(Path(__file__).resolve().parents[1]))  # add backend/ to path
from utils.opensmile_utils import (
    extract_opensmile_dataframe,
    dataframe_to_vector,
)

# Default raw directory (used as --input_dir default)
RAW_DIR = Path("data/raw")
FEATURE_ROOT = Path("data/features")

VALID_FEATURE_SETS = {"egemaps", "compare_2016", "compare"}
VALID_LEVELS = {"func", "lld"}
VALID_AGG = {"none", "mean", "std", "meanstd", "median"}


def parse_args():
    p = argparse.ArgumentParser(description="Batch extract OpenSMILE features")
    p.add_argument("--feature_set", default="egemaps", help="egemaps | compare_2016")
    p.add_argument("--level", default="func", help="func | lld")
    p.add_argument("--aggregate", default="meanstd", help="Aggregation if level=lld (mean|std|meanstd|median|none)")
    p.add_argument("--overwrite", action="store_true", help="Overwrite existing CSVs")
    p.add_argument("--limit", type=int, default=0, help="Optional limit on number of files")
    # NEW: custom input directory
    p.add_argument("--input_dir", default=str(RAW_DIR), help="Directory root to scan recursively for .wav files (default data/raw)")
    return p.parse_args()


def normalise_feature_set(name: str) -> str:
    n = name.lower()
    if n in {"compare", "compare_2016", "compare2016"}:
        return "compare_2016"
    return "egemaps" if n.startswith("ege") else "egemaps" if n == "egemaps" else n


def main():
    args = parse_args()
    feature_set = normalise_feature_set(args.feature_set)

    if feature_set not in VALID_FEATURE_SETS:
        print(f"Invalid --feature_set {feature_set}. Choices: {sorted(VALID_FEATURE_SETS)}", file=sys.stderr)
        return 2
    if args.level not in VALID_LEVELS:
        print(f"Invalid --level {args.level}. Choices: {sorted(VALID_LEVELS)}", file=sys.stderr)
        return 2
    if args.level == "lld" and args.aggregate not in VALID_AGG:
        print(f"Invalid --aggregate {args.aggregate}. Choices: {sorted(VALID_AGG)}", file=sys.stderr)
        return 2

    raw_dir = Path(args.input_dir).expanduser().resolve()
    if not raw_dir.exists():
        print(f"Input directory not found: {raw_dir}", file=sys.stderr)
        return 1

    out_dir = FEATURE_ROOT / feature_set
    out_dir.mkdir(parents=True, exist_ok=True)

    wav_files = sorted([p for p in raw_dir.rglob("*.wav")])
    if args.limit > 0:
        wav_files = wav_files[: args.limit]

    if not wav_files:
        print(f"No WAV files found under {raw_dir}.")
        return 0

    print(f"Processing {len(wav_files)} files from {raw_dir} -> {out_dir}")

    failures = 0
    for i, wav_path in enumerate(wav_files, 1):
        rel_name = wav_path.stem
        out_csv = out_dir / f"{rel_name}.csv"
        if out_csv.exists() and not args.overwrite:
            continue
        try:
            df = extract_opensmile_dataframe(
                str(wav_path), feature_set=feature_set if feature_set != "compare_2016" else "ComParE_2016", feature_level=args.level
            )
            # If functionals: single row; if LLD aggregate
            if args.level == "func":
                row = df.iloc[0]
                row.to_frame().T.to_csv(out_csv, index=False)
            else:
                vec, idx = dataframe_to_vector(df, feature_level="lld", aggregate_if_lld=args.aggregate)
                pd.DataFrame([vec], columns=idx).to_csv(out_csv, index=False)
        except Exception as e:
            failures += 1
            print(f"[WARN] Failed {wav_path}: {e}")
        if i % 50 == 0:
            print(f"  {i}/{len(wav_files)}")

    print(f"Done. Failures={failures}")
    return 0 if failures == 0 else 3


if __name__ == "__main__":
    sys.exit(main())
