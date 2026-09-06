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
