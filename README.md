# Breath Easy Flutter App

## Overview

This Flutter app is designed to help users analyze their breathing patterns and track symptoms. The backend services are powered by Supabase, which provides authentication, database, and storage functionalities.

---

## Supabase Setup

### Prerequisites

- A Supabase account and project
- Supabase CLI installed (`npm install -g supabase`)
- Flutter environment set up

### Supabase Project Configuration

1. Create a new Supabase project at https://app.supabase.com.

2. Obtain your Supabase URL and anon/public API key from the project settings.

3. Configure your Flutter app to use these credentials by setting environment variables or directly in your app's configuration files.

### Database Schema

The app uses the following tables in Supabase:

- **recordings**: Stores audio recording metadata.
- **symptoms**: Stores user symptom logs.
- **exercises**: Stores exercise completion data, including audio recording URLs.
- **alerts**: Stores alert messages for users.

### Example Table Creation SQL

```sql
CREATE TABLE IF NOT EXISTS recordings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  file_url text NOT NULL,
  category text,
  recorded_at timestamp DEFAULT now(),
  notes text
);

CREATE TABLE IF NOT EXISTS symptoms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  symptom_type text NOT NULL,
  severity int,
  notes text,
  logged_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS exercises (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  exercise_name text NOT NULL,
  completed_at timestamp DEFAULT now(),
  recording_url text
);

CREATE TABLE IF NOT EXISTS alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  alert_type text NOT NULL,
  message text,
  created_at timestamp DEFAULT now(),
  is_resolved boolean DEFAULT false
);
```

### Row-Level Security (RLS)

Enable RLS on all tables and define policies to restrict data access to authenticated users:

```sql
ALTER TABLE recordings ENABLE ROW LEVEL SECURITY;
ALTER TABLE symptoms ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
```

Example policies for SELECT and INSERT:

```sql
CREATE POLICY "Allow user to view own recordings"
ON recordings
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Allow user to insert own recordings"
ON recordings
FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

Repeat similar policies for other tables.

---

## Flutter App Configuration

- Use the `supabase_flutter` package for integration.
- Initialize Supabase client with your project URL and anon key.
- Use Supabase Auth for user authentication.
- Store audio recordings in Supabase Storage under the `recordings` bucket.
- Store metadata including recording URLs in the `exercises` table.

---

## Running the App

1. Ensure your Supabase backend is set up and running.
2. Configure your Flutter app with Supabase credentials.
3. Run the app using:

```bash
flutter run
```

---

## Notes

- Replace any Firebase references with Supabase equivalents.
- Ensure your Supabase storage bucket permissions and RLS policies are correctly configured.
- For local development, you can use Supabase CLI to run a local instance.

---

This README provides the necessary setup and configuration details for using Supabase as the backend for the Breath Easy Flutter app.

---

## Flutter App Documentation

### Overview

The Breath Easy Flutter app provides a user interface for breathing analysis, symptom tracking, and exercise recording. It integrates with Supabase for backend services including authentication, data storage, and file uploads.

### Features

- User authentication with Supabase Auth
- Audio recording and upload to Supabase Storage
- Exercise data management with metadata stored in Supabase database
- Symptom logging and history tracking
- Real-time updates and notifications

### Setup Instructions

1. Ensure you have Flutter SDK installed and configured.
2. Clone the repository and navigate to the project root.
3. Run `flutter pub get` to install dependencies.
4. Configure Supabase credentials in the app (e.g., in environment variables or config files).
5. Run the app on your device or emulator using `flutter run`.

### Key Files and Directories

- `lib/main.dart`: App entry point and routing setup.
- `lib/services/supabase_auth_service.dart`: Handles Supabase authentication logic.
- `lib/features/exercises/presentation/exercises_screen.dart`: UI and logic for exercise recording and upload.
- `lib/features/breath_analysis/presentation/record_screen.dart`: Audio recording UI.
- `lib/screens/login_screen.dart`: User login and signup UI.
- `lib/screens/splash_screen.dart`: Splash screen with auth state listener.

### Usage Notes

- Users must be authenticated to upload recordings and log exercises.
- Audio files are stored in the Supabase Storage bucket named `recordings`.
- Exercise metadata including recording URLs are stored in the `exercises` table.
- Ensure Supabase RLS policies and storage permissions are correctly configured for secure access.

### Testing

- Test user signup, login, and logout flows.
- Verify audio recording and upload functionality.
- Check that exercise data is correctly saved and retrieved from Supabase.
- Validate UI responsiveness and error handling.

---

This documentation complements the backend setup instructions and provides guidance for working with the Flutter app.
