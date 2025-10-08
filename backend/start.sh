#!/bin/bash
# Render startup script for Breath Easy Backend

echo "🚀 Starting Breath Easy Backend deployment..."

# Ensure we're in the right directory
cd /opt/render/project/src/backend

# List Python files to debug
echo "📁 Python files in backend directory:"
find . -name "*.py" | head -10

# Check if the correct file exists
if [ -f "fastapi_app_improved.py" ]; then
    echo "✅ Found fastapi_app_improved.py"
else
    echo "❌ fastapi_app_improved.py not found!"
    ls -la *.py
    exit 1
fi

# Start the application
echo "🎯 Starting uvicorn with fastapi_app_improved:app"
exec uvicorn fastapi_app_improved:app --host 0.0.0.0 --port $PORT
