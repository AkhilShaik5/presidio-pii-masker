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

# Clean pip cache
echo "Cleaning pip cache..."
pip cache purge

# Uninstall existing numpy if present
echo "Removing existing numpy installation..."
pip uninstall -y numpy

# Install numpy with specific version
echo "Installing numpy..."
pip install --no-cache-dir numpy==1.23.5

# Verify numpy installation
echo "Verifying numpy installation..."
python -c "import numpy; print('Numpy version:', numpy.__version__)" || {
    echo "Failed to import numpy, trying alternative installation..."
    pip uninstall -y numpy
    pip install --no-cache-dir numpy==1.21.6
    python -c "import numpy; print('Numpy version:', numpy.__version__)"
}

# Install other dependencies
echo "Installing other dependencies..."
pip install --no-cache-dir -r requirements.txt

# Install spacy model with error handling
echo "Installing spacy model..."
MODEL_VERSION="3.7.1"
DIRECT_DOWNLOAD="https://github.com/explosion/spacy-models/releases/download/en_core_web_lg-${MODEL_VERSION}/en_core_web_lg-${MODEL_VERSION}.tar.gz"

# Try multiple installation methods
(python -m spacy download en_core_web_lg && echo "Successfully installed spacy model via download command") || \
(pip install --no-cache-dir en-core-web-lg==${MODEL_VERSION} && echo "Successfully installed spacy model via pip") || \
(pip install --no-cache-dir "${DIRECT_DOWNLOAD}" && echo "Successfully installed spacy model via direct download") || \
{
    echo "Failed to install large model, falling back to medium model..."
    python -m spacy download en_core_web_md || pip install --no-cache-dir en-core-web-md
}

# Verify spacy and model installation
echo "Verifying spacy installation..."
python -c "import spacy; nlp = spacy.load('en_core_web_lg' if spacy.util.is_package('en_core_web_lg') else 'en_core_web_md'); print('Loaded model:', nlp.meta['name'])" || {
    echo "Failed to load spacy model, trying to repair installation..."
    pip uninstall -y spacy
    pip install --no-cache-dir spacy==${SPACY_VERSION}
    python -m spacy download en_core_web_lg
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