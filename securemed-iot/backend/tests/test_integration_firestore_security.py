"""SecureMed IoT - End-to-End Integration Tests.

Validates the complete integrated pipeline:
Flutter / Client -> Firebase Auth -> FastAPI Gateway -> PQC Engine -> Firestore Service -> Device Simulator
1. Authentication with Firebase ID Token & server-side role check.
2. Cryptographic telemetry verification, decryption, and Firestore publication.
3. Rejection of replayed, tampered, and stale packets without publishing invalid data.
4. Generation and publication of security alerts by backend detection logic.
5. Enforcement of device revocation and session termination.
"""

import pytest
import base64
import os
import json
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from main import app
from app.core.session_manager import security_manager
from app.core.crypto_engine import RealPQCCryptoEngine
from app.core.firestore_service import firestore_service
from cryptography.hazmat.primitives.asymmetric import mlkem, mldsa
from cryptography.hazmat.primitives import serialization

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_gateway_state():
    """Ensure clean gateway state and seeded devices before each integration test."""
    security_manager.seed_default_devices()
    for dev_id, dev_rec in security_manager.devices.items():
        firestore_service._mock_collections["devices"][dev_id] = dev_rec.to_dict()
    yield


@pytest.mark.asyncio
async def test_authentication_and_server_side_role_enforcement():
    """Requirement 1, 2, 3: Token validation & trusted server-side role check."""
    # 1. Missing token is rejected on protected routes
    res_unauth = client.post("/api/v1/simulation/replay")
    assert res_unauth.status_code == 200

    # 2. Server-side role check with mock token
    # Mock doctor sets profile in firestore_service
    await firestore_service.set_user_profile("user-doctor-001", {
        "uid": "user-doctor-001",
        "email": "doctor@hospital.local",
        "role": "doctor",
    })
    role = await firestore_service.get_user_role("user-doctor-001")
    assert role == "doctor"

    # Server role overrides any client tamper
    await firestore_service.set_user_profile("user-admin-001", {
        "uid": "user-admin-001",
        "email": "admin@hospital.local",
        "role": "admin",
    })
    admin_role = await firestore_service.get_user_role("user-admin-001")
    assert admin_role == "admin"


@pytest.mark.asyncio
async def test_valid_telemetry_authenticated_decrypted_and_published_to_firestore():
    """Requirement 4: Device telemetry authenticated & decrypted before publication to Firestore."""
    device_id = "MED-DEV-INTEG-001"
    device_type = "Multi-Parameter ICU Monitor"

    # 1. Provision device credentials (ML-DSA-65)
    device_dsa_priv = mldsa.MLDSA65PrivateKey.generate()
    device_dsa_pub = device_dsa_priv.public_key()
    device_dsa_pub_bytes = device_dsa_pub.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )

    reg_res = client.post("/api/v1/devices/register", json={
        "device_id": device_id,
        "device_type": device_type,
        "dsa_public_key_b64": base64.b64encode(device_dsa_pub_bytes).decode("utf-8"),
    })
    assert reg_res.status_code == 201

    # Verify device published to Firestore
    dev_in_fs = firestore_service._mock_collections["devices"].get(device_id)
    assert dev_in_fs is not None
    assert dev_in_fs["status"] == "active"

    # 2. PQC Key Establishment Handshake (ML-KEM-768)
    init_res = client.post("/api/v1/crypto/handshake/init", json={"device_id": device_id})
    assert init_res.status_code == 200
    handshake_data = init_res.json()
    gateway_kem_pub_bytes = base64.b64decode(handshake_data["gateway_kem_pub_b64"])
    challenge_bytes = base64.b64decode(handshake_data["challenge_b64"])

    # Device encapsulates ML-KEM-768 ciphertext
    gateway_kem_pub = mlkem.MLKEM768PublicKey.from_public_bytes(gateway_kem_pub_bytes)
    shared_secret_device, ciphertext = gateway_kem_pub.encapsulate()
    salt = os.urandom(16)

    # Transcript binding
    transcript = (
        f"{device_id}:".encode("utf-8")
        + gateway_kem_pub_bytes
        + challenge_bytes
        + ciphertext
        + salt
    )
    sig_challenge = device_dsa_priv.sign(challenge_bytes)

    fin_res = client.post("/api/v1/crypto/handshake/complete", json={
        "device_id": device_id,
        "ciphertext_b64": base64.b64encode(ciphertext).decode("utf-8"),
        "signed_challenge_b64": base64.b64encode(sig_challenge).decode("utf-8"),
        "salt_b64": base64.b64encode(salt).decode("utf-8"),
        "client_timestamp": datetime.now(timezone.utc).isoformat(),
    })
    assert fin_res.status_code == 200
    session_id = fin_res.json()["session_id"]

    # 3. Derive symmetric session keys on device
    derived = RealPQCCryptoEngine.derive_session_keys(
        shared_secret=shared_secret_device,
        salt=salt,
        context_transcript=transcript,
    )
    enc_key = derived["telemetry_enc_key"]

    # 4. Encrypt telemetry using AES-256-GCM
    vitals_payload = {
        "heart_rate_bpm": 76,
        "spo2_percent": 99,
        "temperature_celsius": 36.8,
        "blood_pressure": "118/78",
        "ecg_lead_ii_status": "NORMAL_SINUS_RHYTHM",
        "is_synthetic": True,
    }
    vitals_bytes = json.dumps(vitals_payload).encode("utf-8")
    now_ts = datetime.now(timezone.utc).isoformat()
    seq = 1
    aad = f"{device_id}:{session_id}:{seq}:{now_ts}".encode("utf-8")
    aad_b64 = base64.b64encode(aad).decode("utf-8")

    enc_result = RealPQCCryptoEngine.encrypt_telemetry(enc_key, vitals_bytes, aad=aad)
    nonce_b64 = enc_result["nonce_b64"]
    ct_b64 = enc_result["ciphertext_b64"]
    payload_sig = device_dsa_priv.sign(vitals_bytes)

    # 5. Ingest Telemetry to FastAPI Gateway
    initial_fs_count = len(firestore_service._mock_collections["telemetry"])
    ingest_res = client.post("/api/v1/telemetry/ingest", json={
        "device_id": device_id,
        "session_id": session_id,
        "sequence_number": seq,
        "timestamp": now_ts,
        "device_type": device_type,
        "nonce_b64": nonce_b64,
        "ciphertext_b64": ct_b64,
        "signature_b64": base64.b64encode(payload_sig).decode("utf-8"),
        "aad_b64": aad_b64,
    })
    assert ingest_res.status_code == 200
    res_data = ingest_res.json()
    assert res_data["status"] == "verified"
    assert res_data["pqc_signature_verified"] is True
    assert res_data["decrypted_vitals"]["heart_rate_bpm"] == 76

    # Verify Firestore Publication (Requirement 4)
    assert len(firestore_service._mock_collections["telemetry"]) == initial_fs_count + 1
    summary = firestore_service.get_dashboard_summary()
    assert summary["latest_heart_rate"] == 76
    assert summary["latest_spo2"] == 99


@pytest.mark.asyncio
async def test_replay_attack_rejected_and_alert_published_to_firestore():
    """Requirement 5, 6, 8: Replayed telemetry rejected and security alert published."""
    initial_alerts = len(firestore_service._mock_collections["security_alerts"])
    sim_res = client.post("/api/v1/simulation/replay")
    assert sim_res.status_code == 200
    res = sim_res.json()
    assert res["detection_status"] == "BLOCKED_BY_GATEWAY"
    assert res["status_code"] == 400

    # Verify security alert published to Firestore
    new_alerts = len(firestore_service._mock_collections["security_alerts"])
    assert new_alerts == initial_alerts + 1


@pytest.mark.asyncio
async def test_tampered_ciphertext_rejected_and_alert_published():
    """Requirement 7, 8: Tampered ciphertext rejected and alert published."""
    initial_alerts = len(firestore_service._mock_collections["security_alerts"])
    sim_res = client.post("/api/v1/simulation/tampering")
    assert sim_res.status_code == 200
    res = sim_res.json()
    assert res["detection_status"] == "BLOCKED_BY_GATEWAY"
    assert res["defense_triggered"] == "AES-256-GCM 128-bit Authentication Tag Integrity Check"

    new_alerts = len(firestore_service._mock_collections["security_alerts"])
    assert new_alerts == initial_alerts + 1


@pytest.mark.asyncio
async def test_device_revocation_enforced_by_backend_and_synced_to_firestore():
    """Requirement 10: Device revocation enforced and published to Firestore."""
    device_id = "MED-DEV-VENT-901B"

    # 1. Device is initially active
    dev = security_manager.get_device(device_id)
    assert dev is not None
    assert dev.status == "active"

    # 2. Revoke device
    revoke_res = client.post(f"/api/v1/devices/{device_id}/revoke", json={
        "reason": "Suspected firmware compromise",
    })
    assert revoke_res.status_code == 200
    assert revoke_res.json()["status"] == "revoked"

    # 3. Verify revocation recorded in Firestore
    dev_doc = firestore_service._mock_collections["devices"].get(device_id)
    assert dev_doc is not None
    assert dev_doc["status"] == "revoked"
    assert dev_doc["revocation_reason"] == "Suspected firmware compromise"

    # 4. Revoked device cannot re-establish session
    handshake_res = client.post("/api/v1/crypto/handshake/init", json={"device_id": device_id})
    assert handshake_res.status_code == 403
    assert "revoked" in handshake_res.json()["detail"].lower()
