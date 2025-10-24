# Breath Easy - AI-Powered Respiratory Health App

A Flutter mobile application with FastAPI backend for respiratory health analysis using machine learning.

## Features

- 🎙️ **Audio Recording**: Record breath sounds and speech
- 🤖 **AI Analysis**: ML-powered respiratory condition detection
- 📊 **Health Tracking**: Patient history and progress monitoring
- 🏥 **Patient Management**: Comprehensive intake forms and profiles
- 🔐 **Secure Authentication**: Supabase-powered user management

## Tech Stack

**Frontend (Flutter)**
- Flutter 3.x
- Supabase integration
- Audio recording capabilities
- Modern Material Design UI

**Backend (Python)**
- FastAPI framework
- Machine Learning (scikit-learn)
- Audio processing (librosa, opensmile)
- Supabase database integration

## Quick Setup

### Prerequisites
- Flutter SDK
- Python 3.11+
- Supabase account

### Local Development
1. Clone repository
2. Install Flutter dependencies: `flutter pub get`
3. Install Python dependencies: `cd backend && pip install -r requirements.txt`
4. Configure Supabase credentials
5. Run backend: `cd backend && uvicorn app.main:app --reload`
6. Run Flutter app: `flutter run`

### Cloud Deployment
Ready for deployment on Railway, Vercel, or Heroku with included configuration files.

## Configuration

Set these environment variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Project Structure

```
├── lib/                 # Flutter app source
├── backend/            # Python FastAPI backend
├── supabase/          # Database migrations
├── railway.toml       # Railway deployment config
├── vercel.json        # Vercel deployment config
└── Procfile          # Heroku deployment config
```
