#!/usr/bin/env python3
"""
Test script for API endpoints
"""
import requests
import json
import sys
import os

def test_health_endpoint():
    """Test the health check endpoint"""
    try:
        response = requests.get('http://localhost:8000/api/v1/health', timeout=10)
        print(f'Health check status: {response.status_code}')
        if response.status_code == 200:
            data = response.json()
            print('Health response:', json.dumps(data, indent=2))
            return True
        else:
            print('Health check failed')
            return False
    except Exception as e:
        print(f'Error testing health endpoint: {e}')
        return False

def test_unified_endpoint():
    """Test the unified analysis endpoint"""
    try:
        # Use the created test audio file
        with open('test_audio.wav', 'rb') as f:
            files = {'file': ('test_audio.wav', f, 'audio/wav')}
            data = {'task_type': 'breath'}

            response = requests.post('http://localhost:8000/api/v1/unified', files=files, data=data, timeout=30)
            print(f'Unified endpoint status: {response.status_code}')

            if response.status_code == 200:
                result = response.json()
                print('Unified response:', json.dumps(result, indent=2))
                return True
            else:
                print(f'Unified request failed: {response.text}')
                return False
    except Exception as e:
        print(f'Error testing unified endpoint: {e}')
        return False

def main():
    print("Testing API endpoints...")

    # Test health endpoint
    health_ok = test_health_endpoint()
    print()

    # Test unified endpoint
    unified_ok = test_unified_endpoint()
    print()

    if health_ok and unified_ok:
        print("✅ All tests passed!")
        return 0
    else:
        print("❌ Some tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
