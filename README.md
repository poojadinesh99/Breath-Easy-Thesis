---
title: Breath Easy Backend
emoji: 🫁
colorFrom: blue
colorTo: indigo
sdk: docker
app_file: main_app.py
pinned: false
---

# 🫁 Breath Easy Thesis App

![Flutter](https://img.shields.io/badge/Made_with-Flutter-blue?logo=flutter)
![FastAPI](https://img.shields.io/badge/API-FastAPI-green?logo=fastapi)
![Hugging Face](https://img.shields.io/badge/Hosted_on-HuggingFace-yellow?logo=huggingface)

---

## 🧠 Project Overview

**Breath Easy** is a cross-platform mobile application and backend system that:
- Captures audio of breathing/speech
- Extracts features using OpenSMILE
- Uses a trained Random Forest model to predict respiratory conditions
- Supports both WAV file input and real-time microphone input
- Offers an intuitive Flutter-based UI for patients

---

## 📱 Frontend – Flutter App

The Flutter app provides:
- 🔘 Home screen with live recording
- ✅ Symptom Tracker
- 🧑‍⚕️ Patient Profile
- 📈 AI Predictions from backend API
- 📡 Supabase authentication (optional)

### 🔧 Getting Started with Flutter

```bash
flutter pub get
flutter run
```

### 📚 Resources
- [Flutter Codelabs](https://docs.flutter.dev/codelabs)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Flutter API Reference](https://api.flutter.dev/)

---

## ⚙️ Backend – FastAPI (Hugging Face Space)

The backend is built with FastAPI and hosted via Hugging Face.

### 🔌 Prediction Endpoint

```http
POST /predict
Content-Type: multipart/form-data

Field: file=<WAV audio>
Field: task_type=breath
```

### ✅ Example Response

```json
{
  "label": "Asthmatic",
  "confidence": 0.92,
  "text_summary": "Symptoms consistent with mild wheezing",
  "possible_conditions": ["Asthma", "Bronchitis"]
}
```

### 🔍 Other Routes
- `GET /` – Health Check
- `GET /docs` – OpenAPI docs (Swagger)

### 🛠️ Architecture

```
Flutter App --> FastAPI Backend --> RF Model + OpenSMILE
                            |
                            --> Hugging Face Space (Docker)
```

### 📦 Deployment Notes
- Hugging Face Space is configured via the YAML block at the top of this file.
- Backend `app_file` is `main_app.py`, and is containerized with Docker.
- Whisper transcription only runs when source is a file path (not in-memory array).
- `/predict` accepts `task_type=breath` or `task_type=speech` depending on your model needs.

---

## 🎓 Author
Pooja Dinesh  
👩‍🎓 Master's in Data Science – FAU Erlangen-Nürnberg  
🧪 Thesis Project (2025)  
📬 pooja.dinesh@fau.de  
🌐 [Hugging Face Space](https://huggingface.co/spaces/pooja-dinesh/breath-easy)

## 📝 License
This project is for academic use. For reproduction, citation, or collaboration, please contact the author.
