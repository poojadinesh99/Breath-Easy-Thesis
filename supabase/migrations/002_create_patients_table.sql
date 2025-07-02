-- Migration script to create patients table for patient intake form data

CREATE TABLE IF NOT EXISTS patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  age int NOT NULL,
  contactNumber text NOT NULL,
  consentGiven boolean NOT NULL DEFAULT false,
  hasPreviousConditions boolean NOT NULL DEFAULT false,
  isSmoker boolean NOT NULL DEFAULT false,
  hasRespiratoryDiseaseHistory boolean NOT NULL DEFAULT false,
  exposedToCovid boolean NOT NULL DEFAULT false,
  vaccinated boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to select their own patient record
CREATE POLICY "Allow users to select their own patient record"
ON patients
FOR SELECT
USING (auth.uid() = user_id);

-- Policy to allow users to insert their own patient record
CREATE POLICY "Allow users to insert their own patient record"
ON patients
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy to allow users to update their own patient record
CREATE POLICY "Allow users to update their own patient record"
ON patients
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
