-- Migration to fix RLS policies for patients table
-- File: 20241016_fix_rls_policies.sql

-- First, disable RLS temporarily to clear existing policies
ALTER TABLE patients DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Users can insert own patient data" ON patients;
DROP POLICY IF EXISTS "Users can view own patient data" ON patients;
DROP POLICY IF EXISTS "Users can update own patient data" ON patients;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON patients;
DROP POLICY IF EXISTS "Enable read access for users" ON patients;

-- Re-enable RLS
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

-- Create permissive policies that allow both authenticated and anonymous users
CREATE POLICY "Allow all operations for authenticated users" ON patients
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all operations for anonymous users" ON patients
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

-- Grant full permissions
GRANT ALL ON patients TO authenticated;
GRANT ALL ON patients TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

-- Ensure sequences are accessible
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;
