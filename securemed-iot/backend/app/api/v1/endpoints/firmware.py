"""SecureMed IoT - Firmware Integrity & NIST FIPS 204 ML-DSA-65 Attestation Endpoint.

Verifies:
1. SHA-256 binary cryptographic fingerprint.
2. ML-DSA-65 quantum-resistant vendor firmware signature.
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
import base64
from datetime import datetime, timezone

from app.core.crypto_engine import RealPQCCryptoEngine
from app.core.session_manager import security_manager

router = APIRouter()


class FirmwareVerifyRequest(BaseModel):
    firmware_name: str = Field(..., json_schema_extra={"example": "SecureMed-RTOS-Patch-v2.4.1"})
    version: str = Field(..., json_schema_extra={"example": "2.4.1-pqc"})
    firmware_image_b64: str = Field(..., description="Base64 encoded raw firmware binary")
    vendor_signature_b64: str = Field(..., description="ML-DSA-65 3,309-byte signature base64 encoded")
    vendor_dsa_pub_b64: str = Field(..., description="ML-DSA-65 1,952-byte public key base64 encoded")
    expected_sha256: Optional[str] = Field(None, description="Optional expected SHA-256 hex fingerprint")


class FirmwareVerifyResponse(BaseModel):
    firmware_name: str
    version: str
    sha256_fingerprint: str
    size_bytes: int
    signature_verified: bool
    status: str
    verified_at: str


@router.post("/verify", response_model=FirmwareVerifyResponse, summary="Verify Firmware SHA-256 & ML-DSA-65 Signature")
async def verify_firmware_package(req: FirmwareVerifyRequest):
    """
    Cryptographically verifies firmware updates before deployment to connected patient monitors:
    1. SHA-256 binary hash fingerprint calculation.
    2. Optional pre-distribution hash match verification.
    3. Post-Quantum NIST FIPS 204 (ML-DSA-65) signature verification against the vendor signing key.
    4. Tamper-evident audit chain logging.
    """
    try:
        raw_firmware = base64.b64decode(req.firmware_image_b64)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid base64 encoding in firmware_image_b64")

    # 1. Compute SHA-256 fingerprint
    computed_sha256 = RealPQCCryptoEngine.compute_sha256(raw_firmware)

    if req.expected_sha256 and req.expected_sha256.lower() != computed_sha256.lower():
        security_manager._record_security_incident(
            "FIRMWARE_SHA256_MISMATCH",
            req.firmware_name,
            None,
            f"Firmware hash mismatch: expected {req.expected_sha256}, got {computed_sha256}",
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Firmware binary integrity compromised. Expected SHA-256 {req.expected_sha256}, computed {computed_sha256}.",
        )

    # 2. Verify ML-DSA-65 vendor digital signature
    try:
        vendor_pub_bytes = base64.b64decode(req.vendor_dsa_pub_b64)
        vendor_pub = RealPQCCryptoEngine.deserialize_dsa_public_key(vendor_pub_bytes)
        signature_bytes = base64.b64decode(req.vendor_signature_b64)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Malformed vendor key or signature: {str(e)}",
        )

    sig_valid = RealPQCCryptoEngine.dsa_verify(
        public_key=vendor_pub,
        signature=signature_bytes,
        message=raw_firmware,
    )

    if not sig_valid:
        security_manager._record_security_incident(
            "FIRMWARE_SIGNATURE_INVALID",
            req.firmware_name,
            None,
            "ML-DSA-65 firmware signature verification failed. Unauthorized firmware binary detected.",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firmware signature verification failed. Binary is not signed by trusted vendor key.",
        )

    verified_at = datetime.now(timezone.utc).isoformat()
    security_manager._record_audit_event(
        "FIRMWARE_VERIFIED",
        req.firmware_name,
        {
            "version": req.version,
            "sha256": computed_sha256,
            "size_bytes": len(raw_firmware),
        },
    )

    return FirmwareVerifyResponse(
        firmware_name=req.firmware_name,
        version=req.version,
        sha256_fingerprint=computed_sha256,
        size_bytes=len(raw_firmware),
        signature_verified=True,
        status="trusted_and_verified",
        verified_at=verified_at,
    )
