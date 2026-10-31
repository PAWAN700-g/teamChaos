from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
import json
import base64
from datetime import datetime, timezone

from app.core.crypto_engine import RealPQCCryptoEngine
from app.core.session_manager import security_manager
from app.core.firestore_service import firestore_service

router = APIRouter()

# In-memory store of recent telemetry & alerts for prototype demo
_RECENT_TELEMETRY: List[Dict[str, Any]] = []
_DETECTED_ALERTS: List[Dict[str, Any]] = []


class TelemetryIngestRequest(BaseModel):
    device_id: str = Field(..., json_schema_extra={"example": "MED-DEV-ICU-701A"})
    session_id: str = Field(..., json_schema_extra={"example": "SES-1234567890abcdef"})
    sequence_number: int = Field(..., ge=1, json_schema_extra={"example": 1})
    timestamp: str = Field(..., json_schema_extra={"example": "2026-10-31T15:30:00Z"})
    device_type: str = Field(default="ICU_PATIENT_MONITOR")
    nonce_b64: str = Field(..., description="12-byte AES-GCM nonce base64 encoded")
    ciphertext_b64: str = Field(..., description="AES-256-GCM ciphertext + 16-byte tag base64 encoded")
    signature_b64: str = Field(..., description="ML-DSA-65 signature on plaintext payload base64 encoded")
    aad_b64: str = Field(..., description="Authenticated Associated Data (device_id:session_id:seq:ts) base64 encoded")


class TelemetryIngestResponse(BaseModel):
    status: str
    device_id: str
    session_id: str
    sequence_number: int
    decrypted_vitals: Dict[str, Any]
    pqc_signature_verified: bool
    tampering_detected: bool
    ingested_at: str


@router.post("/ingest", response_model=TelemetryIngestResponse, summary="Ingest Post-Quantum Encrypted Telemetry")
async def ingest_telemetry(req: TelemetryIngestRequest):
    """
    Ingests and authenticates telemetry envelope:
    1. Replay & Freshness Protection: Sequence monotonicity, nonce freshness, and ±60s clock skew window.
    2. AAD Integrity: Validates bound device_id, session_id, sequence_number, timestamp.
    3. AES-256-GCM Decryption: Verifies 128-bit authentication tag.
    4. NIST FIPS 204 ML-DSA-65 Signature: Verifies device attestation on decrypted medical payload.
    5. Tamper-evident Audit Logging: Appends entry to SHA-256 cryptographic audit chain.
    """
    # 1. Validate envelope through SecurityStateManager (checks device revocation, session TTL, replay, nonce, freshness)
    is_valid, reason, session = security_manager.validate_incoming_telemetry_envelope(
        session_id=req.session_id,
        device_id=req.device_id,
        sequence_number=req.sequence_number,
        timestamp_iso=req.timestamp,
        nonce_b64=req.nonce_b64,
    )

    if not is_valid:
        if reason == "DEVICE_IS_REVOKED":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Device '{req.device_id}' credentials have been revoked. Transmission rejected.",
            )
        elif reason in ("SESSION_NOT_FOUND", "SESSION_DEVICE_MISMATCH"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid or active session missing for device '{req.device_id}'. Handshake required.",
            )
        elif reason == "SESSION_EXPIRED":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="PQC cryptographic session expired. Re-authentication required.",
            )
        else:
            # Replay attack, nonce reuse, or freshness window violation
            alert = {
                "alert_id": f"ALT-{datetime.now(timezone.utc).timestamp()}",
                "device_id": req.device_id,
                "severity": "critical",
                "attack_type": "REPLAY_OR_FRESHNESS_VIOLATION",
                "description": reason,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            _DETECTED_ALERTS.append(alert)
            await firestore_service.publish_security_alert(alert)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=reason,
            )

    # 2. Verify AAD format and matching parameters
    expected_aad = f"{req.device_id}:{req.session_id}:{req.sequence_number}:{req.timestamp}".encode("utf-8")
    try:
        provided_aad = base64.b64decode(req.aad_b64)
        if provided_aad != expected_aad:
            security_manager._record_security_incident(
                "AAD_TAMPERING_DETECTED",
                req.device_id,
                req.session_id,
                "Provided AAD does not match the bound envelope header fields",
            )
            alert = {
                "alert_id": f"ALT-{datetime.now(timezone.utc).timestamp()}",
                "device_id": req.device_id,
                "severity": "critical",
                "attack_type": "AAD_TAMPERING_DETECTED",
                "description": "Provided AAD does not match the bound envelope header fields",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            _DETECTED_ALERTS.append(alert)
            await firestore_service.publish_security_alert(alert)
            raise ValueError("AAD parameter mismatch")
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="AAD verification failed: Associated data does not match bound envelope fields.",
        )

    # 3. Decrypt AES-256-GCM ciphertext using derived session key
    try:
        decrypted_bytes = RealPQCCryptoEngine.decrypt_telemetry(
            session_key=session.telemetry_enc_key,
            nonce_b64=req.nonce_b64,
            ciphertext_b64=req.ciphertext_b64,
            aad_b64=req.aad_b64,
        )
    except Exception as e:
        alert = {
            "alert_id": f"ALT-{datetime.now(timezone.utc).timestamp()}",
            "device_id": req.device_id,
            "severity": "critical",
            "attack_type": "MITM_CIPHERTEXT_TAMPERING",
            "description": f"AES-256-GCM authentication tag mismatch for device {req.device_id}. Telemetry rejected.",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        _DETECTED_ALERTS.append(alert)
        await firestore_service.publish_security_alert(alert)
        security_manager._record_security_incident(
            "MITM_CIPHERTEXT_TAMPERING",
            req.device_id,
            req.session_id,
            f"AES-256-GCM authentication tag mismatch: {str(e)}",
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Decryption failed: GCM authentication tag mismatch or payload tampering: {str(e)}",
        )

    # 4. Verify NIST FIPS 204 ML-DSA-65 signature on the decrypted payload
    device = security_manager.get_device(req.device_id)
    sig_bytes = base64.b64decode(req.signature_b64)
    signature_valid = RealPQCCryptoEngine.dsa_verify(
        public_key=device.dsa_public_key,
        signature=sig_bytes,
        message=decrypted_bytes,
    )

    if not signature_valid:
        alert = {
            "alert_id": f"ALT-{datetime.now(timezone.utc).timestamp()}",
            "device_id": req.device_id,
            "severity": "critical",
            "attack_type": "ML_DSA_SIGNATURE_VERIFICATION_FAILURE",
            "description": f"ML-DSA-65 device signature verification failed for device {req.device_id}.",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        _DETECTED_ALERTS.append(alert)
        await firestore_service.publish_security_alert(alert)
        security_manager._record_security_incident(
            "ML_DSA_SIGNATURE_VERIFICATION_FAILURE",
            req.device_id,
            req.session_id,
            "ML-DSA-65 digital signature on telemetry payload is invalid",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Digital signature verification failed. Telemetry packet was tampered with or device is unauthorized.",
        )

    # 5. Parse medical vitals (synthetic data only)
    try:
        vitals = json.loads(decrypted_bytes.decode("utf-8"))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payload is not valid JSON.",
        )

    # 6. Medical physiological bounds validation (hackathon synthetic telemetry anomaly detection)
    tampering = False
    hr = vitals.get("heart_rate_bpm", 75)
    spo2 = vitals.get("spo2_percent", 98)
    if hr > 170 or hr < 40 or spo2 < 85:
        tampering = True
        anomaly_alert = {
            "alert_id": f"ALT-{datetime.now(timezone.utc).timestamp()}",
            "device_id": req.device_id,
            "severity": "warning",
            "attack_type": "PHYSIOLOGICAL_ANOMALY_INJECTION",
            "description": f"Extreme vital anomaly: HR {hr} bpm, SpO2 {spo2}%.",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        _DETECTED_ALERTS.append(anomaly_alert)
        await firestore_service.publish_security_alert(anomaly_alert)

    record = {
        "device_id": req.device_id,
        "device_type": req.device_type,
        "session_id": req.session_id,
        "sequence_number": req.sequence_number,
        "vitals": vitals,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "pqc_signature_verified": True,
        "tampering_detected": tampering,
    }
    _RECENT_TELEMETRY.append(record)
    if len(_RECENT_TELEMETRY) > 50:
        _RECENT_TELEMETRY.pop(0)

    # Enforce Requirement 4: Authenticated & decrypted telemetry published to Firestore by backend
    await firestore_service.publish_verified_telemetry(record)

    # Record tamper-evident audit log event
    security_manager._record_audit_event(
        "TELEMETRY_INGESTED",
        req.device_id,
        {
            "session_id": req.session_id,
            "sequence_number": req.sequence_number,
            "tampering": tampering,
        },
    )

    return TelemetryIngestResponse(
        status="verified",
        device_id=req.device_id,
        session_id=req.session_id,
        sequence_number=req.sequence_number,
        decrypted_vitals=vitals,
        pqc_signature_verified=True,
        tampering_detected=tampering,
        ingested_at=record["timestamp"],
    )


@router.get("/latest", summary="Get Latest Ingested Telemetry")
async def get_latest_telemetry():
    """Retrieve the latest verified telemetry stream and security incidents."""
    return {
        "telemetry_stream": _RECENT_TELEMETRY[-10:],
        "security_alerts": _DETECTED_ALERTS[-10:],
        "total_packets_ingested": len(_RECENT_TELEMETRY),
        "audit_head_hash": security_manager.audit_head_hash,
    }


@router.get("/audit", summary="Get Tamper-Evident Audit Ledger Chain")
async def get_audit_ledger():
    """Returns full tamper-evident audit ledger with parent hashes and blocks."""
    return {
        "audit_head_hash": security_manager.audit_head_hash,
        "chain_length": len(security_manager.audit_log_chain),
        "events": security_manager.audit_log_chain,
    }


@router.get("/audit/verify", summary="Verify Audit Hash Chain Integrity")
async def verify_audit_ledger():
    """Verifies SHA-256 hash continuity across all audit records."""
    is_intact, message, failure_info = security_manager.verify_audit_chain(include_details=True)
    anchoring_info = security_manager.get_anchoring_digest()
    return {
        "is_intact": is_intact,
        "total_blocks_verified": len(security_manager.audit_log_chain),
        "head_hash": security_manager.audit_head_hash,
        "message": message,
        "corrupted_block": failure_info,
        "limitation_disclosure": anchoring_info["limitation_disclosure"],
    }


@router.get("/audit/anchor", summary="Export Anchoring Digest for External Publication")
async def get_audit_anchor():
    """Exports latest head hash & anchoring digest for external anchoring."""
    return security_manager.get_anchoring_digest()
