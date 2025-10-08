-- Check if analysis_history table exists and create if not
CREATE TABLE IF NOT EXISTS analysis_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    analysis_type VARCHAR(50) DEFAULT 'monitoring',
    label VARCHAR(100),
    confidence DECIMAL(5,4),
    source VARCHAR(50),
    predictions JSONB,
    raw_response JSONB,
    transcript TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE analysis_history ENABLE ROW LEVEL SECURITY;

-- Create policy so users can only see their own data
CREATE POLICY "Users can view their own analysis history" ON analysis_history
    FOR SELECT USING (auth.uid() = user_id);

-- Create policy so users can insert their own data
CREATE POLICY "Users can insert their own analysis history" ON analysis_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_analysis_history_user_created 
ON analysis_history(user_id, created_at DESC);

-- Check current data
SELECT COUNT(*) as total_records FROM analysis_history;
SELECT user_id, analysis_type, label, confidence, created_at 
FROM analysis_history 
ORDER BY created_at DESC 
LIMIT 10;
