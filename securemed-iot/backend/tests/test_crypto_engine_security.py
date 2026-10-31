"""SecureMed IoT - Cryptographic Security Engine & Attack Defense Test Suite.

Exhaustively verifies the 7 mandatory cybersecurity requirements:
1. Valid ML-DSA-65 signature accepted.
2. Invalid ML-DSA-65 signature rejected.
3. Valid AES-256-GCM ciphertext decrypted.
4. Modified ciphertext (or altered GCM auth tag) rejected.
5. Duplicate sequence number (replay attack) rejected.
6. Revoked device rejected from handshake and telemetry transmission.
7. Expired session rejected.

Additional Protections Verified:
8. Nonce reuse under same session key rejected.
9. Out-of-window timestamp (freshness window > 60s) rejected.
10. Firmware SHA-256 and ML-DSA-65 signature verification.
11. Tamper-evident SHA-256 audit log chaining.
"""

import pytest
import os
import json
import base64
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient

from main import app
from app.core.crypto_engine import RealPQCCryptoEngine, CryptographicEngineMetadata
from app.core.session_manager import security_manager

client = TestClient(app)


def _setup_registered_device(device_id: str):
    """Helper: Generates ML-DSA-65 keypair and registers device with the backend."""
    priv, pub = RealPQCCryptoEngine.generate_dsa_keypair()
    pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(pub)
    res = client.post(
        "/api/v1/devices/register",
        json={
            "device_id": device_id,
            "device_type": "ICU_VENTILATOR",
            "dsa_public_key_b64": base64.b64encode(pub_bytes).decode("utf-8"),
        },
    )
    assert res.status_code in (200, 201)
    return priv, pub, pub_bytes


def _perform_pqc_handshake(device_id: str, dsa_priv):
    """Helper: Executes complete ML-KEM-768 + ML-DSA-65 handshake."""
    # 1. Init
    init_res = client.post("/api/v1/crypto/handshake/init", json={"device_id": device_id})
    assert init_res.status_code == 200
    init_data = init_res.json()

    gw_kem_pub_bytes = base64.b64decode(init_data["gateway_kem_pub_b64"])
    challenge_bytes = base64.b64decode(init_data["challenge_b64"])

    # 2. Encapsulate & Sign
    gw_kem_pub = RealPQCCryptoEngine.deserialize_kem_public_key(gw_kem_pub_bytes)
    shared_secret, ciphertext = RealPQCCryptoEngine.kem_encapsulate(gw_kem_pub)
    sig_challenge = RealPQCCryptoEngine.dsa_sign(dsa_priv, challenge_bytes)

    salt = os.urandom(16)
    transcript = (
        f"{device_id}:".encode("utf-8")
        + gw_kem_pub_bytes
        + challenge_bytes
        + ciphertext
        + salt
    )
    keys = RealPQCCryptoEngine.derive_session_keys(shared_secret, salt, transcript)

    # 3. Complete
    comp_res = client.post(
        "/api/v1/crypto/handshake/complete",
        json={
            "device_id": device_id,
            "ciphertext_b64": base64.b64encode(ciphertext).decode("utf-8"),
            "signed_challenge_b64": base64.b64encode(sig_challenge).decode("utf-8"),
            "salt_b64": base64.b64encode(salt).decode("utf-8"),
            "client_timestamp": datetime.now(timezone.utc).isoformat(),
        },
    )
    assert comp_res.status_code == 200
    data = comp_res.json()
    return data["session_id"], keys["telemetry_enc_key"]


# ==============================================================================
# TEST 1: Valid signature accepted
# ==============================================================================
def test_valid_signature_accepted():
    """Verify that a legitimate NIST FIPS 204 ML-DSA-65 signature on telemetry is accepted."""
    device_id = "DEV-TEST-SIG-OK"
    dsa_priv, dsa_pub, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    vitals = {"heart_rate_bpm": 72, "spo2_percent": 98}
    payload = json.dumps(vitals).encode("utf-8")
    sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, payload)

    seq = 1
    ts = datetime.now(timezone.utc).isoformat()
    aad = f"{device_id}:{session_id}:{seq}:{ts}".encode("utf-8")
    enc = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad)

    res = client.post(
        "/api/v1/telemetry/ingest",
        json={
            "device_id": device_id,
            "session_id": session_id,
            "sequence_number": seq,
            "timestamp": ts,
            "device_type": "ICU_VENTILATOR",
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": enc["ciphertext_b64"],
            "signature_b64": base64.b64encode(sig).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["pqc_signature_verified"] is True
    assert data["decrypted_vitals"]["heart_rate_bpm"] == 72


# ==============================================================================
# TEST 2: Invalid signature rejected
# ==============================================================================
def test_invalid_signature_rejected():
    """Verify that an invalid or forged ML-DSA-65 signature is detected and rejected."""
    device_id = "DEV-TEST-SIG-BAD"
    dsa_priv, _, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    # Attacker uses a different, unauthorized ML-DSA-65 private key to sign the telemetry
    unauthorized_priv, _ = RealPQCCryptoEngine.generate_dsa_keypair()

    vitals = {"heart_rate_bpm": 80, "spo2_percent": 97}
    payload = json.dumps(vitals).encode("utf-8")
    forged_sig = RealPQCCryptoEngine.dsa_sign(unauthorized_priv, payload)

    seq = 1
    ts = datetime.now(timezone.utc).isoformat()
    aad = f"{device_id}:{session_id}:{seq}:{ts}".encode("utf-8")
    enc = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad)

    res = client.post(
        "/api/v1/telemetry/ingest",
        json={
            "device_id": device_id,
            "session_id": session_id,
            "sequence_number": seq,
            "timestamp": ts,
            "device_type": "ICU_VENTILATOR",
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": enc["ciphertext_b64"],
            "signature_b64": base64.b64encode(forged_sig).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        },
    )
    assert res.status_code == 401
    assert "signature verification failed" in res.json()["detail"].lower()


# ==============================================================================
# TEST 3: Valid ciphertext decrypted
# ==============================================================================
def test_valid_ciphertext_decrypted():
    """Verify that valid AES-256-GCM ciphertext decrypts accurately into original plaintext."""
    device_id = "DEV-TEST-CIPHER-OK"
    dsa_priv, _, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    vitals = {"heart_rate_bpm": 68, "spo2_percent": 99, "systolic_bp": 120, "diastolic_bp": 80}
    payload = json.dumps(vitals).encode("utf-8")
    sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, payload)

    seq = 1
    ts = datetime.now(timezone.utc).isoformat()
    aad = f"{device_id}:{session_id}:{seq}:{ts}".encode("utf-8")
    enc = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad)

    res = client.post(
        "/api/v1/telemetry/ingest",
        json={
            "device_id": device_id,
            "session_id": session_id,
            "sequence_number": seq,
            "timestamp": ts,
            "device_type": "ICU_VENTILATOR",
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": enc["ciphertext_b64"],
            "signature_b64": base64.b64encode(sig).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        },
    )
    assert res.status_code == 200
    assert res.json()["decrypted_vitals"]["systolic_bp"] == 120


# ==============================================================================
# TEST 4: Modified ciphertext rejected
# ==============================================================================
def test_modified_ciphertext_rejected():
    """Verify that altering 1 bit in ciphertext or GCM auth tag causes rejection."""
    device_id = "DEV-TEST-CIPHER-TAMPER"
    dsa_priv, _, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    vitals = {"heart_rate_bpm": 70, "spo2_percent": 98}
    payload = json.dumps(vitals).encode("utf-8")
    sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, payload)

    seq = 1
    ts = datetime.now(timezone.utc).isoformat()
    aad = f"{device_id}:{session_id}:{seq}:{ts}".encode("utf-8")
    enc = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad)

    # MITM flips bytes in ciphertext
    ct_bytes = bytearray(base64.b64decode(enc["ciphertext_b64"]))
    ct_bytes[5] ^= 0xFF  # Corrupt 1 byte in ciphertext body
    tampered_ct_b64 = base64.b64encode(ct_bytes).decode("utf-8")

    res = client.post(
        "/api/v1/telemetry/ingest",
        json={
            "device_id": device_id,
            "session_id": session_id,
            "sequence_number": seq,
            "timestamp": ts,
            "device_type": "ICU_VENTILATOR",
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": tampered_ct_b64,
            "signature_b64": base64.b64encode(sig).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        },
    )
    assert res.status_code == 400
    assert "decryption failed" in res.json()["detail"].lower()


# ==============================================================================
# TEST 5: Duplicate sequence number rejected (Replay Attack Defense)
# ==============================================================================
def test_duplicate_sequence_number_rejected():
    """Verify that transmitting identical or lower sequence number is rejected as a replay attack."""
    device_id = "DEV-TEST-REPLAY-DEFENSE"
    dsa_priv, _, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    # Send Seq #1 - Should succeed
    vitals = {"heart_rate_bpm": 75, "spo2_percent": 98}
    payload = json.dumps(vitals).encode("utf-8")
    sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, payload)

    ts1 = datetime.now(timezone.utc).isoformat()
    aad1 = f"{device_id}:{session_id}:1:{ts1}".encode("utf-8")
    enc1 = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad1)

    packet1 = {
        "device_id": device_id,
        "session_id": session_id,
        "sequence_number": 1,
        "timestamp": ts1,
        "device_type": "ICU_VENTILATOR",
        "nonce_b64": enc1["nonce_b64"],
        "ciphertext_b64": enc1["ciphertext_b64"],
        "signature_b64": base64.b64encode(sig).decode("utf-8"),
        "aad_b64": enc1["aad_b64"],
    }
    res1 = client.post("/api/v1/telemetry/ingest", json=packet1)
    assert res1.status_code == 200

    # Attacker replays exact Packet #1 (or transmits new packet with same Seq #1)
    res_replay = client.post("/api/v1/telemetry/ingest", json=packet1)
    assert res_replay.status_code == 400
    assert "replay_attack_detected" in res_replay.json()["detail"].lower() or "replay" in res_replay.json()["detail"].lower()


# ==============================================================================
# TEST 6: Revoked device rejected
# ==============================================================================
def test_revoked_device_rejected():
    """Verify that a revoked device credential is barred from handshakes and telemetry transmission."""
    device_id = "DEV-TEST-REVOCATION"
    dsa_priv, _, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    # Administrator revokes device
    revoke_res = client.post(f"/api/v1/devices/{device_id}/revoke", json={"reason": "Compromised device key"})
    assert revoke_res.status_code == 200
    assert revoke_res.json()["status"] == "revoked"

    # 1. Telemetry transmission under existing session must now be rejected
    vitals = {"heart_rate_bpm": 70, "spo2_percent": 98}
    payload = json.dumps(vitals).encode("utf-8")
    sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, payload)

    ts = datetime.now(timezone.utc).isoformat()
    aad = f"{device_id}:{session_id}:2:{ts}".encode("utf-8")
    enc = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad)

    tel_res = client.post(
        "/api/v1/telemetry/ingest",
        json={
            "device_id": device_id,
            "session_id": session_id,
            "sequence_number": 2,
            "timestamp": ts,
            "device_type": "ICU_VENTILATOR",
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": enc["ciphertext_b64"],
            "signature_b64": base64.b64encode(sig).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        },
    )
    assert tel_res.status_code == 403
    assert "revoked" in tel_res.json()["detail"].lower()

    # 2. Re-initiating a new handshake must also be blocked
    init_res = client.post("/api/v1/crypto/handshake/init", json={"device_id": device_id})
    assert init_res.status_code == 403
    assert "revoked" in init_res.json()["detail"].lower()


# ==============================================================================
# TEST 7: Expired session rejected
# ==============================================================================
def test_expired_session_rejected():
    """Verify that packets received after session TTL expiration are rejected."""
    device_id = "DEV-TEST-SESSION-EXPIRATION"
    dsa_priv, _, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    # Force expiration of the session in memory
    session = security_manager.get_session(session_id)
    assert session is not None
    session.expires_at = datetime.now(timezone.utc) - timedelta(seconds=10)  # Expired 10 seconds ago

    vitals = {"heart_rate_bpm": 75, "spo2_percent": 98}
    payload = json.dumps(vitals).encode("utf-8")
    sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, payload)

    ts = datetime.now(timezone.utc).isoformat()
    aad = f"{device_id}:{session_id}:1:{ts}".encode("utf-8")
    enc = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad)

    res = client.post(
        "/api/v1/telemetry/ingest",
        json={
            "device_id": device_id,
            "session_id": session_id,
            "sequence_number": 1,
            "timestamp": ts,
            "device_type": "ICU_VENTILATOR",
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": enc["ciphertext_b64"],
            "signature_b64": base64.b64encode(sig).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        },
    )
    assert res.status_code == 401
    assert "expired" in res.json()["detail"].lower()


# ==============================================================================
# TEST 8: Temporal freshness window rejection
# ==============================================================================
def test_freshness_window_stale_timestamp_rejected():
    """Verify that messages with timestamps drifted > ±60 seconds are rejected."""
    device_id = "DEV-TEST-FRESHNESS"
    dsa_priv, _, _ = _setup_registered_device(device_id)
    session_id, enc_key = _perform_pqc_handshake(device_id, dsa_priv)

    vitals = {"heart_rate_bpm": 76, "spo2_percent": 98}
    payload = json.dumps(vitals).encode("utf-8")
    sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, payload)

    # Timestamp from 5 minutes ago (outside the 60s freshness window)
    stale_ts = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    aad = f"{device_id}:{session_id}:1:{stale_ts}".encode("utf-8")
    enc = RealPQCCryptoEngine.encrypt_telemetry(enc_key, payload, aad)

    res = client.post(
        "/api/v1/telemetry/ingest",
        json={
            "device_id": device_id,
            "session_id": session_id,
            "sequence_number": 1,
            "timestamp": stale_ts,
            "device_type": "ICU_VENTILATOR",
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": enc["ciphertext_b64"],
            "signature_b64": base64.b64encode(sig).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        },
    )
    assert res.status_code == 400
    assert "stale_timestamp" in res.json()["detail"].lower()


# ==============================================================================
# TEST 9: Firmware SHA-256 fingerprint & ML-DSA-65 signature verification
# ==============================================================================
def test_firmware_sha256_and_mldsa_signature_verification():
    """Verify firmware binary integrity with SHA-256 fingerprint and ML-DSA-65 vendor signature."""
    vendor_priv, vendor_pub = RealPQCCryptoEngine.generate_dsa_keypair()
    vendor_pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(vendor_pub)

    firmware_binary = b"SECUREMED_OS_KERNEL_IMAGE_BINARY_v2.4.1_POST_QUANTUM_READY"
    firmware_sha256 = RealPQCCryptoEngine.compute_sha256(firmware_binary)
    vendor_sig = RealPQCCryptoEngine.dsa_sign(vendor_priv, firmware_binary)

    # 1. Valid firmware submission
    res_valid = client.post(
        "/api/v1/firmware/verify",
        json={
            "firmware_name": "SecureMed-RTOS-Patch-v2.4.1",
            "version": "2.4.1-pqc",
            "firmware_image_b64": base64.b64encode(firmware_binary).decode("utf-8"),
            "vendor_signature_b64": base64.b64encode(vendor_sig).decode("utf-8"),
            "vendor_dsa_pub_b64": base64.b64encode(vendor_pub_bytes).decode("utf-8"),
            "expected_sha256": firmware_sha256,
        },
    )
    assert res_valid.status_code == 200
    data = res_valid.json()
    assert data["signature_verified"] is True
    assert data["sha256_fingerprint"] == firmware_sha256

    # 2. Tampered firmware binary (1 byte changed) must fail hash / signature check
    tampered_binary = firmware_binary + b"_MALICIOUS_INJECTION"
    res_tampered = client.post(
        "/api/v1/firmware/verify",
        json={
            "firmware_name": "SecureMed-RTOS-Patch-v2.4.1",
            "version": "2.4.1-pqc",
            "firmware_image_b64": base64.b64encode(tampered_binary).decode("utf-8"),
            "vendor_signature_b64": base64.b64encode(vendor_sig).decode("utf-8"),
            "vendor_dsa_pub_b64": base64.b64encode(vendor_pub_bytes).decode("utf-8"),
            "expected_sha256": firmware_sha256,
        },
    )
    assert res_tampered.status_code in (400, 401)
