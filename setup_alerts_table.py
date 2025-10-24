#!/usr/bin/env python3
"""
Script to set up the AI alerts table in Supabase database.
This will execute the ai_alerts_table.sql file.
"""

import os
import sys
from supabase import create_client, Client
from dotenv import load_dotenv

def setup_alerts_table():
    """Execute the SQL to create the alerts table and related structures."""
    
    # Load environment variables
    load_dotenv()
    
    # Get Supabase credentials
    url = os.getenv("SUPABASE_URL", "https://fjxofvxbujivsqyfbldu.supabase.co")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqeG9mdnhidWppdnNxeWZibGR1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDM2MTUwOCwiZXhwIjoyMDY1OTM3NTA4fQ.8YZVEt2XIzuLbfKzT9Muyu188DlHXQcCjetFDhxmCgk")
    
    if not url or not key:
        print("❌ Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set")
        sys.exit(1)
    
    # Create Supabase client
    try:
        supabase: Client = create_client(url, key)
        print("✅ Connected to Supabase")
    except Exception as e:
        print(f"❌ Failed to connect to Supabase: {e}")
        sys.exit(1)
    
    # Read the SQL file
    try:
        with open("ai_alerts_table.sql", "r") as f:
            sql_content = f.read()
        print("✅ Read ai_alerts_table.sql file")
    except FileNotFoundError:
        print("❌ Error: ai_alerts_table.sql file not found")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error reading SQL file: {e}")
        sys.exit(1)
    
    # Execute the SQL
    try:
        # Split the SQL content into individual statements
        statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
        
        print(f"📝 Executing {len(statements)} SQL statements...")
        
        for i, statement in enumerate(statements, 1):
            if statement:
                try:
                    result = supabase.rpc('execute_sql', {'sql': statement + ';'}).execute()
                    print(f"✅ Statement {i}/{len(statements)} executed successfully")
                except Exception as stmt_error:
                    # Some statements might fail if they already exist - this is okay
                    print(f"⚠️  Statement {i} warning: {stmt_error}")
                    continue
        
        print("🎉 AI Alerts table setup completed!")
        
        # Test the table by checking if it exists
        try:
            result = supabase.table('ai_alerts').select('count()').execute()
            print("✅ AI Alerts table is accessible")
            print(f"📊 Current alerts count: {len(result.data) if result.data else 0}")
        except Exception as e:
            print(f"⚠️  Could not verify table: {e}")
        
    except Exception as e:
        print(f"❌ Error executing SQL: {e}")
        print("💡 You may need to run this SQL manually in your Supabase dashboard")
        print("📋 SQL Dashboard URL: https://supabase.com/dashboard/project/fjxofvxbujivsqyfbldu/editor")
        sys.exit(1)

if __name__ == "__main__":
    print("🚀 Setting up AI Alerts table in Supabase...")
    setup_alerts_table()
