from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_root_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "SecureMed IoT" in data["message"]


def test_health_check_endpoint():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "ML-KEM-768" in data["cryptography"]["kem_algorithm"]
    assert "ML-DSA-65" in data["cryptography"]["dsa_algorithm"]
    assert "HACKATHON PROTOTYPE" in data["disclaimer"]
