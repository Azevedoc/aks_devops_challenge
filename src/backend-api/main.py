"""Simple demo backend API."""
import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def root():
    return jsonify({
        "service": "backend-api",
        "status": "healthy",
        "version": os.getenv("VERSION", "1.0.0")
    })

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/ready")
def ready():
    return jsonify({"status": "ready"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
