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
