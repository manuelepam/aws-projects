from flask import Flask, Response, jsonify
from prometheus_client import CONTENT_TYPE_LATEST, Gauge, generate_latest

app = Flask(__name__)


TURBINES = [
    {"id": "ZW-001", "status": "operational"},
    {"id": "ZW-002", "status": "maintenance_required"},
    {"id": "ZW-003", "status": "operational"},
]

TURBINES_REQUIRING_MAINTENANCE = Gauge(
    "zephyrworks_turbines_requiring_maintenance",
    "Number of turbines currently requiring maintenance",
)

TURBINES_REQUIRING_MAINTENANCE.set(
    sum(turbine["status"] == "maintenance_required" for turbine in TURBINES)
)

@app.get("/")
def index():
    return jsonify(
        {
            "company": "ZephyrWorks Energy",
            "service": "Turbine Maintenance API",
            "status": "operational",
            "version": "1.0.1",
        }
    )


@app.get("/health")
def health():
    return jsonify({"status": "healthy"})


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), content_type=CONTENT_TYPE_LATEST)

@app.get("/turbines")
def turbines():
    return jsonify({"count": len(TURBINES), "turbines": TURBINES})
