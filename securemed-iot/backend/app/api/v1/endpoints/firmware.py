"""SecureMed IoT - Post-Quantum Firmware Integrity & Anti-Rollback Endpoints.

Implements:
1. Generation and signing of synthetic test firmware packages using NIST FIPS 204 ML-DSA-65.
2. SHA-256 binary fingerprint calculation & integrity validation.
3. Trusted Vendor Keystore enforcement (strict unknown key rejection).
4. Monotonic Anti-Rollback version checking (rejects prohibited older versions).
5. Comprehensive audit event and SIEM alert recording.
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List

from app.core.firmware_service import firmware_service

router = APIRouter()


class SyntheticFirmwareGenerateRequest(BaseModel):
    firmware_name: str = Field(default="SecureMed-RTOS-Patch-v2.4.1")
    version: str = Field(default="2.4.1")
    min_allowed_version: str = Field(default="2.0.0")
    vendor_key_id: str = Field(default="VENDOR-SECUREMED-PRIMARY")
    use_untrusted_key: bool = Field(default=False, description="Simulate an untrusted rogue key signature")


class FirmwareVerifyRequest(BaseModel):
    firmware_name: str = Field(..., json_schema_extra={"example": "SecureMed-RTOS-Patch-v2.4.1"})
    version: str = Field(..., json_schema_extra={"example": "2.4.1"})
    firmware_image_b64: str = Field(..., description="Base64 encoded raw firmware binary")
    vendor_signature_b64: str = Field(..., description="ML-DSA-65 3,309-byte signature base64 encoded")
    vendor_dsa_pub_b64: str = Field(..., description="ML-DSA-65 1,952-byte public key base64 encoded")
    expected_sha256: Optional[str] = Field(None, description="Optional expected SHA-256 hex fingerprint")
    vendor_key_id: Optional[str] = Field(None, description="Optional vendor keystore key ID")


class FirmwareVerifyResponse(BaseModel):
    firmware_name: str
    version: str
    sha256_fingerprint: str
    size_bytes: int
    vendor_key_id: Optional[str] = None
    vendor_authority: Optional[str] = None
    signature_verified: bool
    anti_rollback_verified: bool = True
    min_allowed_version: Optional[str] = None
    status: str
    verified_at: str


@router.post("/generate-synthetic", summary="Generate & Sign Synthetic Test Firmware Package")
async def generate_synthetic_firmware(req: SyntheticFirmwareGenerateRequest):
    """
    Generates a realistic synthetic firmware package, computes SHA-256 fingerprint,
    and signs it with post-quantum ML-DSA-65.
    Never represents code as real patient or medical device software.
    """
    return firmware_service.generate_synthetic_firmware(
        firmware_name=req.firmware_name,
        version=req.version,
        min_allowed_version=req.min_allowed_version,
        vendor_key_id=req.vendor_key_id,
        use_untrusted_key=req.use_untrusted_key,
    )


@router.post("/verify", response_model=FirmwareVerifyResponse, summary="Verify Firmware SHA-256 & ML-DSA-65 Signature")
async def verify_firmware_package(req: FirmwareVerifyRequest):
    """
    Cryptographically verifies firmware updates before deployment to connected patient monitors:
    1. Computes SHA-256 binary hash fingerprint.
    2. Rejects modified firmware with altered hash.
    3. Rejects unknown vendor public keys not registered in the Trusted Vendor Keystore.
    4. Rejects prohibited older versions (Anti-Rollback protection).
    5. Verifies Post-Quantum NIST FIPS 204 (ML-DSA-65) digital signature.
    6. Records verification event into SHA-256 tamper-evident audit ledger and publishes SIEM alerts.
    """
    result = await firmware_service.verify_and_accept_firmware(
        firmware_name=req.firmware_name,
        version=req.version,
        firmware_image_b64=req.firmware_image_b64,
        vendor_signature_b64=req.vendor_signature_b64,
        vendor_dsa_pub_b64=req.vendor_dsa_pub_b64,
        expected_sha256=req.expected_sha256,
        vendor_key_id=req.vendor_key_id,
    )
    return FirmwareVerifyResponse(**result)


@router.get("/trusted-keys", summary="List Authorized Vendor Signing Public Keys")
async def list_trusted_vendor_keys():
    """Retrieve public list of authorized vendor signing keys from the Trusted Keystore."""
    return {
        "trusted_keys": firmware_service.get_trusted_keystore_summary(),
        "total_keys": len(firmware_service.trusted_keystore),
        "algorithm": "ML-DSA-65 (NIST FIPS 204)",
    }


class RegisterVendorKeyRequest(BaseModel):
    key_id: str = Field(..., json_schema_extra={"example": "VENDOR-CUSTOM-01"})
    vendor_name: str = Field(..., json_schema_extra={"example": "Custom Medical Partner"})
    dsa_public_key_b64: str = Field(..., description="ML-DSA-65 1,952-byte public key base64 encoded")


@router.post("/trusted-keys/register", summary="Register Authorized Vendor Signing Key")
async def register_vendor_key(req: RegisterVendorKeyRequest):
    """Registers an authorized vendor signing public key in the Trusted Keystore."""
    try:
        raw_key = base64.b64decode(req.dsa_public_key_b64)
        if len(raw_key) != 1952:
            raise HTTPException(status_code=400, detail="Invalid ML-DSA-65 public key size. Expected exactly 1,952 bytes.")
        firmware_service.register_trusted_vendor_key(req.key_id, req.vendor_name, raw_key)
        return {"status": "registered", "key_id": req.key_id, "vendor_name": req.vendor_name}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/status", summary="Get Firmware Baseline & Anti-Rollback Policies")
async def get_firmware_status():
    """Retrieve active firmware baseline, running versions, and anti-rollback policies."""
    return firmware_service.get_firmware_status()
