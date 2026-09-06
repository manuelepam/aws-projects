from flask import Flask, Response, jsonify
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        {
            "company": "ZephyrWorks Energy",
            "service": "Turbine Maintenance API",
            "status": "operational",
            "version": "1.0.0",
        }
    )


@app.get("/health")
def health():
    return jsonify({"status": "healthy"})


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), content_type=CONTENT_TYPE_LATEST)
