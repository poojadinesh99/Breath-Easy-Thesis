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

## 🔐 Security & Environment Configuration

### ⚠️ Important Security Notice

**A Hugging Face token was previously committed to this repository and has been revoked.** If you forked or cloned this repository before the token was removed, you must:

1. **Rotate any tokens immediately** at [https://hf.co/settings/tokens](https://hf.co/settings/tokens)
2. **Never commit `.env` files** - they are now properly gitignored
3. **Use environment variables or secrets** for all credentials

### 🔑 Setting Up Environment Variables

#### Local Development

1. Copy the example environment files:
   ```bash
   cp .env.example .env
   cp backend/.env.example backend/.env
   cp supabase/.env.example supabase/.env
   ```

2. Fill in your actual credentials in the `.env` files (never commit these!)

3. For Hugging Face token, set `HF_TOKEN` in your `.env` file:
   ```bash
   HF_TOKEN=hf_your_actual_token_here
   ```

   Or export it in your shell:
   ```bash
   export HF_TOKEN=hf_your_actual_token_here
   ```

#### GitHub Actions / CI

Add secrets to your repository:
1. Go to **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Add `HF_TOKEN` with your Hugging Face token value
4. Add other secrets as needed (SUPABASE_URL, SUPABASE_KEY, etc.)

#### Hugging Face Space

Add secrets to your Space:
1. Go to your Space **Settings → Variables and secrets**
2. Add `HF_TOKEN` and any other required secrets
3. These will be available as environment variables at runtime

### 🧹 Removing Secrets from Git History (For Repository Admins)

**Note:** The following steps require force-pushing and will rewrite history. Coordinate with all contributors first.

#### Option 1: Using git-filter-repo (Recommended)

```bash
# Install git-filter-repo
pip install git-filter-repo

# Remove all .env files from history in one command
git filter-repo --path backend/.env --path supabase/.env --path huggingface_space/.env --path .env --invert-paths

# Force push (⚠️ requires coordination with team)
git push --force --all
```

#### Option 2: Using BFG Repo-Cleaner

```bash
# Download BFG from https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files .env

# Clean up and force push
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force --all
```

#### Option 3: Safe Alternative (No History Rewrite)

If you prefer not to rewrite history:
1. ✅ Rotate all exposed credentials immediately at [https://hf.co/settings/tokens](https://hf.co/settings/tokens)
2. ✅ The secrets are now removed from the working tree and future commits
3. ✅ Update team members to use the new tokens
4. ⚠️ Note: Old commits will still contain the secrets, but they'll be invalid

### 📋 Checklist for Contributors

- [ ] Never commit `.env` files
- [ ] Always use `.env.example` as a template
- [ ] Store real credentials in environment variables or secrets
- [ ] Rotate tokens if accidentally committed
- [ ] Review changes before pushing to ensure no secrets are included

---

## 🎓 Author
Pooja Dinesh  
👩‍🎓 Master's in Data Science – FAU Erlangen-Nürnberg  
🧪 Thesis Project (2025)  
📬 pooja.dinesh@fau.de  
🌐 [Hugging Face Space](https://huggingface.co/spaces/pooja-dinesh/breath-easy)

## 📝 License
This project is for academic use. For reproduction, citation, or collaboration, please contact the author.
