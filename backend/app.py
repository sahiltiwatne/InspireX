from flask import Flask, request, jsonify
from ml_pipeline import process_idea
from flask_cors import CORS

app = Flask(__name__)
CORS(app)


@app.route('/process', methods=['POST'])
def process():
    data = request.json
    text = data.get('text', '')
    
    result = process_idea(text)
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)