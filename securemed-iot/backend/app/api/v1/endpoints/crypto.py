from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional
from datetime import datetime, timezone
import base64
import os

from app.core.crypto_engine import RealPQCCryptoEngine, CryptographicEngineMetadata
from app.core.session_manager import security_manager

router = APIRouter()

# Pending handshakes stored in gateway memory: { device_id: { "kem_priv": ..., "challenge": ..., "timestamp": ..., "gateway_pub_bytes": ... } }
_PENDING_HANDSHAKES: Dict[str, Dict[str, Any]] = {}


class HandshakeInitRequest(BaseModel):
    device_id: str = Field(..., json_schema_extra={"example": "MED-DEV-ICU-701A"})


class HandshakeInitResponse(BaseModel):
    device_id: str
    gateway_kem_pub_b64: str
    challenge_b64: str
    timestamp: str
    pqc_algorithm: str = "ML-KEM-768 (NIST FIPS 203)"


class HandshakeCompleteRequest(BaseModel):
    device_id: str
    ciphertext_b64: str = Field(..., description="ML-KEM-768 1,088-byte ciphertext in base64")
    signed_challenge_b64: str = Field(..., description="ML-DSA-65 3,309-byte signature on the challenge")
    salt_b64: str = Field(..., description="16-byte random salt in base64")
    client_timestamp: str


class HandshakeCompleteResponse(BaseModel):
    status: str
    device_id: str
    session_id: str
    session_established: bool
    symmetric_cipher: str = "AES-256-GCM"
    expires_in_seconds: int = 3600
    handshake_transcript_hash: str


@router.get("/info", summary="Cryptographic Engine Specifications & Versions")
async def get_crypto_engine_info():
    """Returns actual library versions, algorithm identifiers, and security parameters."""
    return CryptographicEngineMetadata.get_info()


@router.post("/handshake/init", response_model=HandshakeInitResponse, summary="Initiate Post-Quantum Handshake")
async def initiate_handshake(req: HandshakeInitRequest):
    """Generates Gateway ML-KEM-768 key pair and a random challenge for device attestation."""
    device = security_manager.get_device(req.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device '{req.device_id}' is not registered. Register device public key first.",
        )
    if device.is_revoked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Device '{req.device_id}' has been revoked. All access denied.",
        )

    # Generate ephemeral ML-KEM-768 key pair for this handshake
    kem_priv, kem_pub = RealPQCCryptoEngine.generate_kem_keypair()
    pub_bytes = RealPQCCryptoEngine.serialize_kem_public_key(kem_pub)

    # 32-byte cryptographically secure random challenge
    challenge = os.urandom(32)
    timestamp = datetime.now(timezone.utc).isoformat()

    _PENDING_HANDSHAKES[req.device_id] = {
        "kem_priv": kem_priv,
        "challenge": challenge,
        "timestamp": timestamp,
        "gateway_pub_bytes": pub_bytes,
        "created_at": datetime.now(timezone.utc),
    }

    return HandshakeInitResponse(
        device_id=req.device_id,
        gateway_kem_pub_b64=base64.b64encode(pub_bytes).decode("utf-8"),
        challenge_b64=base64.b64encode(challenge).decode("utf-8"),
        timestamp=timestamp,
    )


@router.post("/handshake/complete", response_model=HandshakeCompleteResponse, summary="Complete Post-Quantum Handshake")
async def complete_handshake(req: HandshakeCompleteRequest):
    """Verifies ML-DSA-65 challenge signature, decapsulates ML-KEM-768 secret, and establishes session."""
    device = security_manager.get_device(req.device_id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not registered")
    if device.is_revoked:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Device is revoked")

    pending = _PENDING_HANDSHAKES.pop(req.device_id, None)
    if not pending:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No active handshake found for device")

    # Check handshake expiration (60 seconds TTL)
    if (datetime.now(timezone.utc) - pending["created_at"]).total_seconds() > 60:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Handshake challenge expired")

    challenge = pending["challenge"]

    # 1. Verify device's ML-DSA-65 digital signature on challenge using registered public key
    sig_bytes = base64.b64decode(req.signed_challenge_b64)
    sig_valid = RealPQCCryptoEngine.dsa_verify(
        public_key=device.dsa_public_key,
        signature=sig_bytes,
        message=challenge,
    )
    if not sig_valid:
        security_manager._record_security_incident(
            incident_type="HANDSHAKE_SIGNATURE_VERIFICATION_FAILED",
            device_id=req.device_id,
            session_id=None,
            description="ML-DSA-65 signature on handshake challenge failed verification",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Device identity authentication failed: Invalid ML-DSA-65 signature on challenge.",
        )

    # 2. Decapsulate ML-KEM-768 ciphertext
    try:
        ciphertext = base64.b64decode(req.ciphertext_b64)
        if len(ciphertext) != 1088:
            raise ValueError(f"ML-KEM-768 ciphertext must be 1,088 bytes (got {len(ciphertext)})")
        shared_secret = RealPQCCryptoEngine.kem_decapsulate(pending["kem_priv"], ciphertext)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"ML-KEM-768 decapsulation failed: {str(e)}")

    # 3. Construct Handshake Transcript Binding
    salt = base64.b64decode(req.salt_b64)
    transcript = (
        f"{req.device_id}:".encode("utf-8")
        + pending["gateway_pub_bytes"]
        + challenge
        + ciphertext
        + salt
    )
    transcript_hash = RealPQCCryptoEngine.compute_sha256(transcript)

    # 4. Create and bind session with HKDF-derived keys
    session = security_manager.create_session(
        device_id=req.device_id,
        shared_secret=shared_secret,
        salt=salt,
        transcript_bytes=transcript,
        ttl_seconds=3600,
    )

    return HandshakeCompleteResponse(
        status="authenticated",
        device_id=req.device_id,
        session_id=session.session_id,
        session_established=True,
        handshake_transcript_hash=transcript_hash,
    )


@router.get("/status", summary="Cryptographic Self-Test")
async def verify_crypto():
    """Runs a live verification of ML-KEM-768, ML-DSA-65, HKDF, and AES-256-GCM."""
    try:
        # ML-KEM-768
        kem_priv, kem_pub = RealPQCCryptoEngine.generate_kem_keypair()
        shared_secret_sender, ciphertext = RealPQCCryptoEngine.kem_encapsulate(kem_pub)
        shared_secret_receiver = RealPQCCryptoEngine.kem_decapsulate(kem_priv, ciphertext)
        assert shared_secret_sender == shared_secret_receiver

        # ML-DSA-65
        dsa_priv, dsa_pub = RealPQCCryptoEngine.generate_dsa_keypair()
        msg = b"SecureMedPQCHealthCheck"
        sig = RealPQCCryptoEngine.dsa_sign(dsa_priv, msg)
        assert RealPQCCryptoEngine.dsa_verify(dsa_pub, sig, msg)

        # HKDF & AES-256-GCM
        salt = os.urandom(16)
        keys = RealPQCCryptoEngine.derive_session_keys(shared_secret_sender, salt, b"context")
        enc = RealPQCCryptoEngine.encrypt_telemetry(keys["telemetry_enc_key"], b'{"vitals": 99}', aad=b"test-aad")
        dec = RealPQCCryptoEngine.decrypt_telemetry(keys["telemetry_enc_key"], enc["nonce_b64"], enc["ciphertext_b64"], enc["aad_b64"])
        assert dec == b'{"vitals": 99}'

        return {
            "pqc_ready": True,
            "algorithms": CryptographicEngineMetadata.get_info()["algorithms"],
            "test_handshake_successful": True,
            "active_pqc_sessions": len(security_manager.active_sessions),
            "registered_devices": len(security_manager.devices),
            "total_security_incidents": len(security_manager.incidents),
            "audit_chain_length": len(security_manager.audit_log_chain),
            "audit_head_hash": security_manager.audit_head_hash,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Crypto self-test failed: {str(e)}")
