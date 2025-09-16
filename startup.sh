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

# Handle Azure App Service directory structure
if [ -d "/home/site/repository" ]; then
    echo "Found repository at /home/site/repository"
    SITE_DIR="/home/site/repository"
elif [ -d "/home/site/wwwroot" ]; then
    echo "Found application at /home/site/wwwroot"
    SITE_DIR="/home/site/wwwroot"
else
    echo "Error: Could not find application directory"
    exit 1
fi

# Set working directory
echo "Changing to directory: $SITE_DIR"
cd $SITE_DIR

# List directory contents for debugging
echo "Current directory contents:"
ls -la

# Check if requirements.txt exists
if [ ! -f requirements.txt ]; then
    echo "Warning: requirements.txt not found in current directory"
    echo "Searching in parent directories..."
    REQUIREMENTS_FILE=$(find / -name requirements.txt -type f 2>/dev/null | head -n 1)
    if [ -z "$REQUIREMENTS_FILE" ]; then
        echo "Error: requirements.txt not found anywhere"
        exit 1
    else
        echo "Found requirements.txt at: $REQUIREMENTS_FILE"
        cp "$REQUIREMENTS_FILE" ./requirements.txt
    fi
fi

# Check if app.py exists
if [ ! -f app.py ]; then
    echo "Warning: app.py not found in current directory"
    echo "Searching in parent directories..."
    APP_FILE=$(find / -name app.py -type f 2>/dev/null | head -n 1)
    if [ -z "$APP_FILE" ]; then
        echo "Error: app.py not found anywhere"
        exit 1
    else
        echo "Found app.py at: $APP_FILE"
        cp "$APP_FILE" ./app.py
    fi
fi

# Activate virtual environment if it exists
if [ -d "antenv" ]; then
    echo "Activating virtual environment: antenv"
    source antenv/bin/activate
fi

# Install dependencies
echo "Installing dependencies..."
python -m pip install --upgrade pip setuptools wheel

# Install numpy first to avoid version conflicts
echo "Installing numpy..."
pip install --no-cache-dir numpy>=1.24.0

# Install other dependencies
echo "Installing other dependencies..."
pip install --no-cache-dir -r requirements.txt

# Verify numpy installation
echo "Verifying numpy installation..."
python -c "import numpy; print('Numpy version:', numpy.__version__)"

# Install spacy model with error handling
echo "Installing spacy model..."
python -m spacy download en_core_web_lg || {
    echo "Failed to install spacy model, trying alternative installation..."
    pip install --no-cache-dir https://github.com/explosion/spacy-models/releases/download/en_core_web_lg-3.7.1/en_core_web_lg-3.7.1-py3-none-any.whl || {
        echo "Failed to install spacy model, continuing anyway..."
    }
}

# Create templates directory if it doesn't exist
mkdir -p templates

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
    --chdir "$SITE_DIR" \
    app:app