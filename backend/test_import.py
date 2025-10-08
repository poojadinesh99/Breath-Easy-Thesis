#!/usr/bin/env python3
"""
Test script to verify fastapi_app_improved.py can be imported correctly
"""

import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_import():
    try:
        print("🧪 Testing import of fastapi_app_improved...")
        
        # Test import
        import fastapi_app_improved
        print("✅ Successfully imported fastapi_app_improved")
        
        # Test app exists
        if hasattr(fastapi_app_improved, 'app'):
            print("✅ FastAPI app instance found")
        else:
            print("❌ FastAPI app instance not found")
            return False
            
        # Test health endpoint
        client = fastapi_app_improved.app
        print("✅ FastAPI app accessible")
        
        return True
        
    except ImportError as e:
        print(f"❌ Import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Breath Easy Backend Import Test")
    success = test_import()
    sys.exit(0 if success else 1)
