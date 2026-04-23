from flask import Flask, jsonify
import socket, datetime

app = Flask(__name__)

# Health check endpoint for Kubernetes
@app.route('/health')
def health():
    return jsonify({
        "status": "ok",
        "node": socket.gethostname(),
        "time": str(datetime.datetime.now())
    })

# Main data endpoint
@app.route('/data')
def data():
    return jsonify({"message": "Hello from Worker-App (Debian)"})