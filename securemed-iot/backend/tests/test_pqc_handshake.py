from fastapi.testclient import TestClient
from main import app
import base64
import os
import json
from datetime import datetime, timezone

from cryptography.hazmat.primitives.asymmetric import mlkem, mldsa
from cryptography.hazmat.primitives import serialization
from app.core.crypto_engine import RealPQCCryptoEngine

client = TestClient(app)


def test_full_pqc_handshake_and_telemetry_flow():
    device_id = "TEST-ICU-MONITOR-01"

    # Step 0: Generate Device ML-DSA-65 identity keypair and register with backend
    device_dsa_priv = mldsa.MLDSA65PrivateKey.generate()
    device_dsa_pub = device_dsa_priv.public_key()
    device_dsa_pub_bytes = device_dsa_pub.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )
    reg_res = client.post("/api/v1/devices/register", json={
        "device_id": device_id,
        "device_type": "ICU_PATIENT_MONITOR",
        "dsa_public_key_b64": base64.b64encode(device_dsa_pub_bytes).decode("utf-8"),
    })
    assert reg_res.status_code in (200, 201)
    assert reg_res.json()["status"] == "active"

    # Step 1: Handshake Init
    init_res = client.post("/api/v1/crypto/handshake/init", json={"device_id": device_id})
    assert init_res.status_code == 200
    init_data = init_res.json()
    gateway_kem_pub_bytes = base64.b64decode(init_data["gateway_kem_pub_b64"])
    challenge_bytes = base64.b64decode(init_data["challenge_b64"])

    # Step 2: Device encapsulates shared secret and signs challenge with ML-DSA-65
    gateway_kem_pub = mlkem.MLKEM768PublicKey.from_public_bytes(gateway_kem_pub_bytes)
    shared_secret_device, ciphertext = gateway_kem_pub.encapsulate()
    sig_challenge = device_dsa_priv.sign(challenge_bytes)
    salt = os.urandom(16)

    # Transcript binding: device_id + gateway_pub + challenge + ciphertext + salt
    transcript = (
        f"{device_id}:".encode("utf-8")
        + gateway_kem_pub_bytes
        + challenge_bytes
        + ciphertext
        + salt
    )
    keys = RealPQCCryptoEngine.derive_session_keys(
        shared_secret=shared_secret_device,
        salt=salt,
        context_transcript=transcript,
    )
    device_session_key = keys["telemetry_enc_key"]

    # Step 3: Complete Handshake
    comp_res = client.post("/api/v1/crypto/handshake/complete", json={
        "device_id": device_id,
        "ciphertext_b64": base64.b64encode(ciphertext).decode("utf-8"),
        "signed_challenge_b64": base64.b64encode(sig_challenge).decode("utf-8"),
        "salt_b64": base64.b64encode(salt).decode("utf-8"),
        "client_timestamp": datetime.now(timezone.utc).isoformat(),
    })
    assert comp_res.status_code == 200
    session_data = comp_res.json()
    assert session_data["session_established"] is True
    session_id = session_data["session_id"]

    # Step 4: Encrypt and Ingest Telemetry
    vitals = {"patient_id": "SYN-PT-100", "heart_rate_bpm": 74, "spo2_percentage": 99}
    vitals_bytes = json.dumps(vitals).encode("utf-8")
    vitals_sig = device_dsa_priv.sign(vitals_bytes)

    seq = 1
    ts = datetime.now(timezone.utc).isoformat()
    aad = f"{device_id}:{session_id}:{seq}:{ts}".encode("utf-8")

    enc_result = RealPQCCryptoEngine.encrypt_telemetry(
        key=device_session_key,
        plaintext=vitals_bytes,
        aad=aad,
    )

    telemetry_res = client.post("/api/v1/telemetry/ingest", json={
        "device_id": device_id,
        "session_id": session_id,
        "sequence_number": seq,
        "timestamp": ts,
        "device_type": "ICU_PATIENT_MONITOR",
        "nonce_b64": enc_result["nonce_b64"],
        "ciphertext_b64": enc_result["ciphertext_b64"],
        "signature_b64": base64.b64encode(vitals_sig).decode("utf-8"),
        "aad_b64": enc_result["aad_b64"],
    })
    assert telemetry_res.status_code == 200, f"Error: {telemetry_res.text}"
    res_data = telemetry_res.json()
    assert res_data["pqc_signature_verified"] is True
    assert res_data["decrypted_vitals"]["heart_rate_bpm"] == 74
