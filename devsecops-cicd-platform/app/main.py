from flask import Flask, jsonify

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
