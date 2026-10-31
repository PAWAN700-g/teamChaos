import pytest
import os
from app.core.security import PQCCryptoEngine


def test_ml_kem_768_key_encapsulation():
    """Verify NIST FIPS 203 ML-KEM-768 key generation, encapsulation, and decapsulation."""
    priv, pub = PQCCryptoEngine.generate_kem_keypair()
    assert priv is not None
    assert pub is not None

    # Device encapsulates secret using server public key
    shared_secret_device, ciphertext = PQCCryptoEngine.kem_encapsulate(pub)
    assert len(shared_secret_device) == 32
    assert len(ciphertext) > 0

    # Server decapsulates secret using private key
    shared_secret_server = PQCCryptoEngine.kem_decapsulate(priv, ciphertext)
    assert shared_secret_device == shared_secret_server


def test_ml_dsa_65_digital_signature():
    """Verify NIST FIPS 204 ML-DSA-65 signature generation and verification."""
    priv, pub = PQCCryptoEngine.generate_dsa_keypair()
    telemetry_message = b'{"device_id": "MED-DEV-ICU-701A", "telemetry": "SYNTHETIC_DATA"}'

    signature = PQCCryptoEngine.dsa_sign(priv, telemetry_message)
    assert len(signature) > 0

    # Verification success
    assert PQCCryptoEngine.dsa_verify(pub, signature, telemetry_message) is True

    # Tampered message must fail verification
    tampered_message = b'{"device_id": "MED-DEV-ICU-701A", "telemetry": "TAMPERED_DATA"}'
    assert PQCCryptoEngine.dsa_verify(pub, signature, tampered_message) is False


def test_hkdf_sha256_and_aes_256_gcm_telemetry_pipeline():
    """Verify end-to-end PQC-derived symmetric session encryption for patient telemetry."""
    # Step 1: PQC KEM shared secret
    priv, pub = PQCCryptoEngine.generate_kem_keypair()
    shared_secret_device, ciphertext = PQCCryptoEngine.kem_encapsulate(pub)

    # Step 2: HKDF-SHA-256 derivation
    salt = os.urandom(16)
    session_key = PQCCryptoEngine.derive_session_key(shared_secret_device, salt=salt)
    assert len(session_key) == 32

    # Step 3: AES-256-GCM encryption of synthetic vitals
    vitals_payload = b'{"patient_id": "SYN-PT-902", "hr": 78, "spo2": 99, "nibp": "120/80"}'
    aad = b"device_id:MED-DEV-ICU-701A"

    enc_result = PQCCryptoEngine.encrypt_telemetry(session_key, vitals_payload, aad=aad)
    assert "nonce" in enc_result
    assert "ciphertext" in enc_result
    assert "aad" in enc_result

    # Step 4: AES-256-GCM decryption
    decrypted_vitals = PQCCryptoEngine.decrypt_telemetry(
        session_key,
        enc_result["nonce"],
        enc_result["ciphertext"],
        enc_result["aad"],
    )
    assert decrypted_vitals == vitals_payload
