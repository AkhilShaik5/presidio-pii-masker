#!/bin/bash
echo "Starting startup script..."
echo "Installing spacy model..."
python -m spacy download en_core_web_lg
echo "Starting gunicorn..."
gunicorn --log-level debug app:app