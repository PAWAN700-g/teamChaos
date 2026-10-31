from fastapi.testclient import TestClient
from fastapi import FastAPI, Depends
from app.core.auth import get_current_user, require_role

# Test app with protected routes
test_app = FastAPI()


@test_app.get("/api/v1/protected/doctor")
async def doctor_endpoint(user: dict = Depends(require_role(["doctor", "admin"]))):
    return {"message": "Welcome Doctor", "user": user}


@test_app.get("/api/v1/protected/admin")
async def admin_endpoint(user: dict = Depends(require_role(["admin"]))):
    return {"message": "Admin Access Granted", "user": user}


client = TestClient(test_app)


def test_missing_token_blocks_access():
    res = client.get("/api/v1/protected/doctor")
    assert res.status_code == 401
    assert "Missing or malformed Authorization header" in res.json()["detail"]


def test_doctor_token_access():
    headers = {"Authorization": "Bearer mock-doctor-token"}
    res = client.get("/api/v1/protected/doctor", headers=headers)
    assert res.status_code == 200
    assert res.json()["user"]["role"] == "doctor"


def test_doctor_forbidden_from_admin_endpoint():
    headers = {"Authorization": "Bearer mock-doctor-token"}
    res = client.get("/api/v1/protected/admin", headers=headers)
    assert res.status_code == 403
    assert "Access denied" in res.json()["detail"]


def test_admin_token_access():
    headers = {"Authorization": "Bearer mock-admin-token"}
    res = client.get("/api/v1/protected/admin", headers=headers)
    assert res.status_code == 200
    assert res.json()["user"]["role"] == "admin"
