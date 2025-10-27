---
title: Breath Easy – Respiratory Sound Analysis
emoji: 🫁
colorFrom: blue
colorTo: green
sdk: static
sdk_version: 1.0.0
app_file: index.html
pinned: false
---

# Breath Easy – Respiratory Sound Analysis

Upload or record a short breathing clip to detect potential respiratory symptoms using machine learning.

## Features

- **Audio Recording**: Record directly from your microphone
- **Real-time Analysis**: Instant prediction of respiratory patterns
- **ML-Powered**: Uses a trained Random Forest model to classify breathing sounds
- **User-Friendly**: Clean, intuitive interface with clear results

## How it works

1. Record or upload a short audio clip of breathing sounds
2. The system extracts MFCC (Mel-Frequency Cepstral Coefficients) features
3. A pre-trained Random Forest model analyzes the features
4. Results are displayed with clear, actionable feedback

## Model Details

- **Algorithm**: Random Forest Classifier
- **Features**: 120-dimensional MFCC features (mean + std of 20 coefficients)
- **Classes**: Normal, Cough, Heavy Breathing, Throat Clearing
- **Training Data**: Respiratory sound dataset

## Usage

Simply click the microphone button to record. The analysis will be performed automatically and results displayed instantly.
