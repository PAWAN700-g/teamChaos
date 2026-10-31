"""SecureMed IoT - Attack Simulation Module Automated Test Suite.

Tests all 8 hostile cybersecurity threat vectors against the local development environment:
1. ATTACK 1: DEVICE IMPERSONATION
   - Rejects unregistered device identity & forged ML-DSA signature.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
2. ATTACK 2: REPLAY ATTACK
   - Rejects duplicate sequence number under active session.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
3. ATTACK 3: TELEMETRY TAMPERING
   - Rejects modified ciphertext / invalid AES-256-GCM authentication tag.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
4. ATTACK 4: UNAUTHORIZED ACCESS
   - Doctor role attempting Admin-only operation returns HTTP 403 Forbidden.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
5. ATTACK 5: FIRMWARE TAMPERING
   - Modified firmware binary fails SHA-256 and ML-DSA signature verification.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
6. ATTACK 6: RATE-LIMIT ATTACK
   - Controlled packet flood simulation triggers HTTP 429 Too Many Requests.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
7. ATTACK 7: DEVICE REVOCATION
   - Revoked device attempting authentication is rejected by gateway CRL check.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
8. ATTACK 8: AUDIT LOG MODIFICATION
   - Tampered audit record triggers SHA-256 hash-chain integrity verification failure.
   - Records simulated input, security mechanism, expected & actual result, generates alert.
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
from app.api.v1.endpoints.telemetry import _DETECTED_ALERTS

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_test_state():
    """Ensure clean gateway security manager state before each test."""
    security_manager.seed_default_devices()
    yield


# ==============================================================================
# ATTACK 1: DEVICE IMPERSONATION
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_1_device_impersonation():
    """Attempt authentication from an unregistered device with an invalid signature."""
    resp = client.post("/api/v1/simulation/device-impersonation")
    assert resp.status_code == 200
    data = resp.json()

    # Verify required reporting fields
    assert "simulated_input" in data and data["simulated_input"]["registered_in_gateway"] is False
    assert "security_mechanism" in data and "ML-DSA-65" in data["security_mechanism"]
    assert "expected_result" in data and "Reject authentication" in data["expected_result"]
    assert "actual_result" in data and "Authentication rejected" in data["actual_result"]
    assert data["status_code"] == 404
    assert data["incident_logged"] is True
    assert data["incident_id"] is not None

    # Verify alias endpoint
    alias_resp = client.post("/api/v1/simulation/fake-device")
    assert alias_resp.status_code == 200

    # Verify alert was generated in memory and published
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "DEVICE_IMPERSONATION_DETECTED"]
    assert len(matching_alerts) > 0

    # Verify real gateway rejection of unregistered device
    rogue_init = client.post(
        "/api/v1/crypto/handshake/init",
        json={"device_id": "ROGUE-DEVICE-UNKNOWN-001"}
    )
    assert rogue_init.status_code == 404


# ==============================================================================
# ATTACK 2: REPLAY ATTACK
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_2_replay_attack():
    """Capture a valid telemetry message and send it again with same session & sequence."""
    resp = client.post("/api/v1/simulation/replay")
    assert resp.status_code == 200
    data = resp.json()

    # Verify reporting fields
    assert "simulated_input" in data
    assert data["simulated_input"]["captured_sequence_number"] == data["simulated_input"]["retransmitted_sequence_number"]
    assert "security_mechanism" in data and "Monotonic Sequence" in data["security_mechanism"]
    assert "expected_result" in data and "Reject duplicate message" in data["expected_result"]
    assert "actual_result" in data and "Duplicate sequence number detected" in data["actual_result"]
    assert data["status_code"] == 400

    # Verify alert generation
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "REPLAY_ATTACK_DETECTED"]
    assert len(matching_alerts) > 0

    # Test real gateway sequence replay defense
    test_priv, test_pub = RealPQCCryptoEngine.generate_dsa_keypair()
    test_dev_id = "MED-DEV-REPLAY-999"
    pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(test_pub)
    security_manager.register_device(test_dev_id, "Replay Test Device", pub_bytes)

    session = security_manager.create_session(
        device_id=test_dev_id,
        shared_secret=os.urandom(32),
        salt=os.urandom(16),
        transcript_bytes=b"handshake_replay_test_context",
    )

    vitals_bytes = json.dumps({"heart_rate_bpm": 72, "spo2_percent": 98, "is_synthetic": True}).encode("utf-8")
    now_ts = datetime.now(timezone.utc).isoformat()
    seq = 1
    aad = f"{test_dev_id}:{session.session_id}:{seq}:{now_ts}".encode("utf-8")

    enc_data = RealPQCCryptoEngine.encrypt_telemetry(
        key=session.telemetry_enc_key,
        plaintext=vitals_bytes,
        aad=aad,
    )
    sig = RealPQCCryptoEngine.dsa_sign(test_priv, vitals_bytes)

    ok_payload = {
        "device_id": test_dev_id,
        "session_id": session.session_id,
        "sequence_number": seq,
        "timestamp": now_ts,
        "device_type": "ICU_MONITOR",
        "nonce_b64": enc_data["nonce_b64"],
        "ciphertext_b64": enc_data["ciphertext_b64"],
        "signature_b64": base64.b64encode(sig).decode("utf-8"),
        "aad_b64": base64.b64encode(aad).decode("utf-8"),
    }
    r1 = client.post("/api/v1/telemetry/ingest", json=ok_payload)
    assert r1.status_code == 200

    # Replay same packet (seq #1)
    r_replay = client.post("/api/v1/telemetry/ingest", json=ok_payload)
    assert r_replay.status_code == 400
    assert "replay" in r_replay.json()["detail"].lower()


# ==============================================================================
# ATTACK 3: TELEMETRY TAMPERING
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_3_telemetry_tampering():
    """Modify ciphertext or authentication tag to verify AES-GCM verification failure."""
    resp = client.post("/api/v1/simulation/tampering")
    assert resp.status_code == 200
    data = resp.json()

    # Verify reporting fields
    assert "simulated_input" in data and "tampered_bytes" in data["simulated_input"]
    assert "security_mechanism" in data and "AES-256-GCM" in data["security_mechanism"]
    assert "expected_result" in data and "AES-GCM verification fails" in data["expected_result"]
    assert "actual_result" in data and "GCM authentication tag mismatch" in data["actual_result"]
    assert data["status_code"] == 400

    # Verify alert generation
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "MITM_CIPHERTEXT_TAMPERING"]
    assert len(matching_alerts) > 0

    # Test real crypto engine tag mismatch
    shared_key = os.urandom(32)
    dev_id = "MED-DEV-ICU-701A"
    plaintext = json.dumps({"vitals": "simulated"}).encode("utf-8")
    aad = f"{dev_id}|test_aad".encode("utf-8")

    enc = RealPQCCryptoEngine.encrypt_telemetry(key=shared_key, plaintext=plaintext, aad=aad)
    raw_ct = base64.b64decode(enc["ciphertext_b64"])

    # Tamper with the last byte (auth tag)
    tampered_ct = bytearray(raw_ct)
    tampered_ct[-1] ^= 0xFF

    with pytest.raises(Exception):
        RealPQCCryptoEngine.decrypt_telemetry(
            key=shared_key,
            nonce_b64=enc["nonce_b64"],
            ciphertext_b64=base64.b64encode(bytes(tampered_ct)).decode("utf-8"),
            aad_b64=enc["aad_b64"],
        )


# ==============================================================================
# ATTACK 4: UNAUTHORIZED ACCESS
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_4_unauthorized_access():
    """Login using a Doctor account and attempt an Admin-only operation."""
    resp = client.post("/api/v1/simulation/unauthorized-access")
    assert resp.status_code == 200
    data = resp.json()

    # Verify reporting fields
    assert "simulated_input" in data
    assert data["simulated_input"]["user_role"] == "doctor"
    assert data["simulated_input"]["required_role"] == "admin"
    assert "security_mechanism" in data and "RBAC" in data["security_mechanism"]
    assert "expected_result" in data and "HTTP 403" in data["expected_result"]
    assert "actual_result" in data and "HTTP 403 Forbidden" in data["actual_result"]
    assert data["status_code"] == 403

    # Verify alias endpoint
    alias_resp = client.post("/api/v1/simulation/unauthorized-command")
    assert alias_resp.status_code == 200

    # Verify alert generation
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "RBAC_PRIVILEGE_ESCALATION"]
    assert len(matching_alerts) > 0

    # Verify real RBAC enforcement: doctor token calling admin-only device revocation
    doctor_headers = {"Authorization": "Bearer mock-doctor-token"}
    r_forbidden = client.post(
        "/api/v1/devices/MED-DEV-ICU-701A/revoke",
        json={"reason": "Unauthorized clinician revocation attempt"},
        headers=doctor_headers
    )
    assert r_forbidden.status_code == 403
    assert "admin privilege required" in r_forbidden.json()["detail"].lower()


# ==============================================================================
# ATTACK 5: FIRMWARE TAMPERING
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_5_firmware_tampering():
    """Modify a test firmware package after signing to test ML-DSA signature verification failure."""
    resp = client.post("/api/v1/simulation/firmware-tampering")
    assert resp.status_code == 200
    data = resp.json()

    # Verify reporting fields
    assert "simulated_input" in data and "tampered_sha256" in data["simulated_input"]
    assert "security_mechanism" in data and "ML-DSA-65" in data["security_mechanism"]
    assert "expected_result" in data and "ML-DSA signature verification fails" in data["expected_result"]
    assert "actual_result" in data and "ML-DSA-65 vendor signature verification failed" in data["actual_result"]
    assert data["status_code"] == 400

    # Verify alert generation
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "FIRMWARE_TAMPERING_DETECTED"]
    assert len(matching_alerts) > 0

    # Test real ML-DSA post-quantum signature verification rejection on tampered payload
    priv, pub = RealPQCCryptoEngine.generate_dsa_keypair()
    original_firmware = b"SecureMed-RTOS-Firmware-Build-v3.0.0-PROD"
    tampered_firmware = b"SecureMed-RTOS-Firmware-Build-v3.0.0-PROD-BACKDOOR"

    sig = RealPQCCryptoEngine.dsa_sign(priv, original_firmware)
    assert RealPQCCryptoEngine.dsa_verify(pub, sig, original_firmware) is True
    # Verification MUST fail on tampered firmware
    assert RealPQCCryptoEngine.dsa_verify(pub, sig, tampered_firmware) is False


# ==============================================================================
# ATTACK 6: RATE-LIMIT ATTACK
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_6_rate_limit_attack():
    """Send a controlled burst of requests to verify HTTP 429 rate limiting."""
    resp = client.post("/api/v1/simulation/rate-limit")
    assert resp.status_code == 200
    data = resp.json()

    # Verify reporting fields
    assert "simulated_input" in data and data["simulated_input"]["burst_packet_count"] == 120
    assert "security_mechanism" in data and "Rate Limiter" in data["security_mechanism"]
    assert "expected_result" in data and "HTTP 429" in data["expected_result"]
    assert "actual_result" in data and "HTTP 429 Too Many Requests" in data["actual_result"]
    assert data["status_code"] == 429

    # Verify alert generation
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "RATE_LIMIT_EXCEEDED"]
    assert len(matching_alerts) > 0


# ==============================================================================
# ATTACK 7: DEVICE REVOCATION
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_7_device_revocation():
    """Revoke a registered test device and attempt another authentication."""
    resp = client.post("/api/v1/simulation/device-revocation")
    assert resp.status_code == 200
    data = resp.json()

    # Verify reporting fields
    assert "simulated_input" in data and data["simulated_input"]["revocation_status"] == "REVOKED"
    assert "security_mechanism" in data and "Revocation Authority" in data["security_mechanism"]
    assert "expected_result" in data and "Authentication rejected" in data["expected_result"]
    assert "actual_result" in data and "HTTP 403 Forbidden" in data["actual_result"]
    assert data["status_code"] == 403

    # Verify alert generation
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "REVOKED_DEVICE_ACCESS_ATTEMPT"]
    assert len(matching_alerts) > 0

    # Test real gateway enforcement on revoked device
    test_dev = "MED-DEV-ICU-701A"
    security_manager.revoke_device(test_dev, reason="Security audit revocation test")

    # Subsequent handshake initialization MUST be rejected with HTTP 403
    r_revoked_init = client.post(
        "/api/v1/crypto/handshake/init",
        json={"device_id": test_dev}
    )
    assert r_revoked_init.status_code == 403
    assert "revoked" in r_revoked_init.json()["detail"].lower()


# ==============================================================================
# ATTACK 8: AUDIT LOG MODIFICATION
# ==============================================================================
@pytest.mark.asyncio
async def test_attack_8_audit_log_modification():
    """Modify a test audit record and verify the hash chain fails integrity verification."""
    resp = client.post("/api/v1/simulation/audit-modification")
    assert resp.status_code == 200
    data = resp.json()

    # Verify reporting fields
    assert "simulated_input" in data and "tampered_payload" in data["simulated_input"]
    assert "security_mechanism" in data and "SHA-256 Hash Chaining" in data["security_mechanism"]
    assert "expected_result" in data and "Integrity verification fails" in data["expected_result"]
    assert "actual_result" in data and "Integrity verification failed" in data["actual_result"]
    assert data["status_code"] == 400

    # Verify alert generation
    matching_alerts = [a for a in _DETECTED_ALERTS if a.get("attack_type") == "AUDIT_LEDGER_INTEGRITY_VIOLATION"]
    assert len(matching_alerts) > 0

    # Test real audit ledger hash chain verification failure when a record is modified
    assert len(security_manager.audit_log_chain) >= 1
    # Verify the untouched chain is valid
    is_valid, reason = security_manager.verify_audit_chain()
    assert is_valid is True

    # Intentionally modify an existing audit record's payload
    target_entry = security_manager.audit_log_chain[-1]
    original_details = target_entry["details"]
    target_entry["details"] = {"tampered": "unauthorized_modification_test"}

    # Verification MUST now fail with broken hash chain
    is_corrupt_valid, fail_reason = security_manager.verify_audit_chain()
    assert is_corrupt_valid is False
    assert "mismatch" in fail_reason.lower() or "broken" in fail_reason.lower()

    # Restore the payload to keep ledger valid for subsequent tests
    target_entry["details"] = original_details
    restored_valid, _ = security_manager.verify_audit_chain()
    assert restored_valid is True
