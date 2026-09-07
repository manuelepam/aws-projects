from app.main import app


def test_index_returns_service_information():
    client = app.test_client()
    response = client.get("/")

    assert response.status_code == 200
    assert response.get_json() == {
        "company": "ZephyrWorks Energy",
        "service": "Turbine Maintenance API",
        "status": "operational",
        "version": "1.0.0",
    }


def test_health_returns_healthy_status():
    client = app.test_client()
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy"}

def test_metrics_returns_prometheus_format():
    client = app.test_client()
    response = client.get("/metrics")

    assert response.status_code == 200
    assert response.content_type.startswith("text/plain")
    assert b"python_info" in response.data
    assert b"zephyrworks_turbines_requiring_maintenance 1.0" in response.data

def test_turbines_returns_maintenance_information():
    client = app.test_client()
    response = client.get("/turbines")
    data = response.get_json()

    assert response.status_code == 200
    assert data["count"] == 3
    assert data["turbines"][1] == {
        "id": "ZW-002",
        "status": "maintenance_required",
    }
