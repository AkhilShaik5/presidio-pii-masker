#!/bin/bash
echo "Starting startup script..."
echo "Installing spacy model..."
python -m spacy download en_core_web_lg
echo "Starting gunicorn..."
#!/bin/bash
echo "Starting application..."

# Create log directory if it doesn't exist
mkdir -p /home/LogFiles

# Enable logging
export WEBSITE_ENABLE_APP_SERVICE_STORAGE=true

# Set environment variables for better container performance
export PYTHONUNBUFFERED=1
export PORT=8000
export WORKERS=2

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Start Gunicorn with proper configuration
echo "Starting Gunicorn server..."
gunicorn --bind=0.0.0.0:8000 \
    --workers=$WORKERS \
    --timeout=600 \
    --access-logfile=/home/LogFiles/access.log \
    --error-logfile=/home/LogFiles/error.log \
    --log-level=info \
    app:app