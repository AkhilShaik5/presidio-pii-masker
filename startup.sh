#!/bin/bash
set -e # Exit on error
echo "Starting startup script..."

# Create log directory if it doesn't exist
mkdir -p /home/LogFiles

# Enable logging
export WEBSITE_ENABLE_APP_SERVICE_STORAGE=true

# Set environment variables for better container performance
export PYTHONUNBUFFERED=1
export PORT=${PORT:-8000}
export WORKERS=${WORKERS:-2}
export TIMEOUT=${TIMEOUT:-600}

# Set working directory to where the app is
cd /home/site/wwwroot

# Check if requirements.txt exists
if [ ! -f requirements.txt ]; then
    echo "Error: requirements.txt not found"
    exit 1
fi

# Check if app.py exists
if [ ! -f app.py ]; then
    echo "Error: app.py not found"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
pip install --no-cache-dir -r requirements.txt

# Install spacy model with error handling
echo "Installing spacy model..."
python -m spacy download en_core_web_lg || {
    echo "Failed to install spacy model, continuing anyway..."
}

# Start Gunicorn with proper configuration
echo "Starting Gunicorn server..."
exec gunicorn \
    --bind=0.0.0.0:$PORT \
    --workers=$WORKERS \
    --timeout=$TIMEOUT \
    --access-logfile=/home/LogFiles/access.log \
    --error-logfile=/home/LogFiles/error.log \
    --capture-output \
    --log-level=debug \
    --preload \
    app:app