from flask import Flask, request, render_template, jsonify
from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine
from typing import Dict, List
import os

app = Flask(__name__)

# Initialize the Presidio engines
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

def analyze_and_mask_text(text: str) -> Dict:
    # Analyze the text
    analyzer_results = analyzer.analyze(
        text=text,
        language='en',
        entities=['PERSON', 'EMAIL_ADDRESS', 'PHONE_NUMBER', 'CREDIT_CARD', 
                 'LOCATION', 'DATE_TIME', 'US_SSN', 'IP_ADDRESS']
    )
    
    # Anonymize the text with the analyzer's results
    anonymized_text = anonymizer.anonymize(
        text=text,
        analyzer_results=analyzer_results
    )

    return {
        'original_text': text,
        'anonymized_text': anonymized_text.text,
        'detected_entities': [
            {
                'entity_type': result.entity_type,
                'start': result.start,
                'end': result.end,
                'score': result.score
            } for result in analyzer_results
        ]
    }

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/mask', methods=['POST'])
def mask_text():
    if request.method == 'POST':
        text = request.form.get('text', '')
        if not text:
            return jsonify({'error': 'No text provided'}), 400
        
        try:
            result = analyze_and_mask_text(text)
            return jsonify(result)
        except Exception as e:
            return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)