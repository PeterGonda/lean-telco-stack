# docker/worker-app/app.py
# Simple Flask application running on the Worker-App node (Debian 12)
from flask import Flask, jsonify
import socket, datetime

app = Flask(__name__)

# Health check endpoint — used by Kubernetes liveness probes
# and the Python monitor to verify the pod is alive
@app.route('/health')
def health():
    return jsonify({
        "status": "ok",
        "node": socket.gethostname(),   # Returns the Pod name
        "time": str(datetime.datetime.now())
    })

# Main data endpoint — simulates a microservice response
@app.route('/data')
def data():
    return jsonify({"message": "Hello from Worker-App (Debian)"})
