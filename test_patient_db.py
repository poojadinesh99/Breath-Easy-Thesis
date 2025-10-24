#!/usr/bin/env python3
"""
Test script to verify patient database schema and insertion
"""
import os
import asyncio
from supabase import create_client, Client

async def test_patient_insertion():
    # Get Supabase credentials from environment or use defaults
    SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://fjxofvxbujivsqyfbldu.supabase.co')
    SUPABASE_ANON_KEY = os.getenv('SUPABASE_ANON_KEY', 'your_anon_key_here')
    
    if SUPABASE_ANON_KEY == 'your_anon_key_here':
        print("❌ Please set SUPABASE_ANON_KEY environment variable")
        return
    
    # Create Supabase client
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
    
    try:
        # Test 1: Check if patients table exists and is accessible
        print("🔍 Testing patients table access...")
        result = supabase.table('patients').select('id').limit(1).execute()
        print(f"✅ Patients table accessible. Found {len(result.data)} records")
        
        # Test 2: Try to create a test user (if needed)
        print("\n🔍 Testing user authentication...")
        try:
            # Try anonymous auth
            auth_response = supabase.auth.sign_in_anonymously()
            user = auth_response.user
            print(f"✅ Anonymous authentication successful. User ID: {user.id}")
        except Exception as e:
            print(f"❌ Anonymous auth failed: {e}")
            print("Trying email auth...")
            
            # Try with email auth
            try:
                auth_response = supabase.auth.sign_up({
                    "email": f"test-{os.urandom(4).hex()}@breatheasy.app",
                    "password": "TestPassword123!"
                })
                user = auth_response.user
                print(f"✅ Email authentication successful. User ID: {user.id}")
            except Exception as e2:
                print(f"❌ Email auth also failed: {e2}")
                return
        
        # Test 3: Try to insert a test patient record
        print("\n🔍 Testing patient record insertion...")
        test_patient = {
            'user_id': user.id,
            'name': 'Test Patient',
            'age': 25,
            'contact_number': '+1234567890',
            'consent_given': True,
            'has_previous_conditions': False,
            'is_smoker': False,
            'has_respiratory_disease_history': False,
            'exposed_to_covid': False,
            'vaccinated': True,
        }
        
        insert_result = supabase.table('patients').insert(test_patient).execute()
        print(f"✅ Patient record inserted successfully. ID: {insert_result.data[0]['id']}")
        
        # Test 4: Clean up - delete the test record
        supabase.table('patients').delete().eq('id', insert_result.data[0]['id']).execute()
        print("✅ Test record cleaned up")
        
        print("\n🎉 All tests passed! Database schema and authentication are working correctly.")
        
    except Exception as e:
        print(f"❌ Database test failed: {e}")
        print(f"Error type: {type(e).__name__}")

if __name__ == "__main__":
    asyncio.run(test_patient_insertion())
