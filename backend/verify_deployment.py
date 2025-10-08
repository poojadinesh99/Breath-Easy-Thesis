#!/usr/bin/env python3
"""
Deployment verification script for Render
This script verifies that the correct files are present and can be imported
"""

import os
import sys

def verify_deployment():
    print("🔍 Verifying Render deployment setup...")
    
    # Check current directory
    current_dir = os.getcwd()
    print(f"📁 Current directory: {current_dir}")
    
    # List files in current directory
    files = os.listdir(current_dir)
    print(f"📋 Files in current directory: {sorted(files)}")
    
    # Check for fastapi_app_improved.py
    if "fastapi_app_improved.py" in files:
        print("✅ fastapi_app_improved.py found")
    else:
        print("❌ fastapi_app_improved.py NOT found")
        return False
    
    # Check for old fastapi_app.py (should NOT exist)
    if "fastapi_app.py" in files:
        print("⚠️ WARNING: Old fastapi_app.py found - this could cause import conflicts")
    else:
        print("✅ Old fastapi_app.py correctly not present")
    
    # Check for extract_spectrogram.py (should NOT exist)
    if "extract_spectrogram.py" in files:
        print("⚠️ WARNING: Old extract_spectrogram.py found - this could cause import conflicts")
    else:
        print("✅ Old extract_spectrogram.py correctly not present")
    
    # Test import
    try:
        print("🧪 Testing import of fastapi_app_improved...")
        import fastapi_app_improved
        print("✅ Successfully imported fastapi_app_improved")
        
        if hasattr(fastapi_app_improved, 'app'):
            print("✅ FastAPI app instance found")
        else:
            print("❌ FastAPI app instance NOT found")
            return False
            
    except Exception as e:
        print(f"❌ Failed to import fastapi_app_improved: {e}")
        return False
    
    print("🎉 All verification checks passed!")
    return True

if __name__ == "__main__":
    success = verify_deployment()
    sys.exit(0 if success else 1)
