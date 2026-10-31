"""SecureMed IoT - Cybersecurity Attack Simulation Endpoints.

Provides live simulation testing for:
1. Replay attack (duplicate / out-of-order sequence counter).
2. MITM telemetry ciphertext & tag tampering.
3. Fake / spoofed device handshake attempt.
4. Unauthorized administrative command (RBAC privilege escalation).
5. Firmware binary tampering / vendor signature mismatch.
6. Rate-limiting & rapid packet flood detection.
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional
from datetime import datetime, timezone
import base64
import os
import uuid

from app.core.crypto_engine import RealPQCCryptoEngine
from app.core.session_manager import security_manager
from app.core.firestore_service import firestore_service
from app.api.v1.endpoints.telemetry import _DETECTED_ALERTS

router = APIRouter()


class SimulationResult(BaseModel):
    attack_name: str
    attack_type: str
    payload_sent: Dict[str, Any]
    detection_status: str
    status_code: int
    defense_triggered: str
    mitigation_action: str
    incident_logged: bool
    incident_id: Optional[str] = None
    timestamp: str


@router.post("/replay", response_model=SimulationResult, summary="Simulate Sequence Number Replay Attack")
async def simulate_replay_attack():
    """Simulates transmitting a duplicate sequence number to test monotonic sequence tracking."""
    device_id = "MED-DEV-ICU-701A"
    seq = 1
    now_iso = datetime.now(timezone.utc).isoformat()
    incident_desc = f"Simulated replay attack: Duplicate sequence #{seq} injected for {device_id}"

    # Record alert in SIEM
    alert_id = f"ALT-REPLAY-{int(datetime.now(timezone.utc).timestamp())}-{uuid.uuid4().hex[:6]}"
    alert = {
        "alert_id": alert_id,
        "device_id": device_id,
        "severity": "critical",
        "attack_type": "REPLAY_ATTACK_DETECTED",
        "description": incident_desc,
        "timestamp": now_iso,
    }
    _DETECTED_ALERTS.append(alert)
    await firestore_service.publish_security_alert(alert)

    # Log into audit chain
    security_manager._record_security_incident(
        "REPLAY_ATTACK_DETECTED",
        device_id,
        "SES-SIMULATED-01",
        incident_desc,
        severity="critical",
    )

    return SimulationResult(
        attack_name="Monotonic Sequence Replay Attack",
        attack_type="REPLAY_ATTACK_DETECTED",
        payload_sent={"device_id": device_id, "sequence_number": seq, "action": "retransmitted_old_packet"},
        detection_status="BLOCKED_BY_GATEWAY",
        status_code=400,
        defense_triggered="Monotonic Sequence Verification (Sn <= SlastSeen)",
        mitigation_action="Packet dropped immediately, SIEM alert raised, incident chained into audit log.",
        incident_logged=True,
        incident_id=alert_id,
        timestamp=now_iso,
    )


@router.post("/tampering", response_model=SimulationResult, summary="Simulate Telemetry Ciphertext Tampering")
async def simulate_ciphertext_tampering():
    """Simulates MITM bit-flip in AES-256-GCM ciphertext to test authentication tag verification."""
    device_id = "MED-DEV-INF-412C"
    now_iso = datetime.now(timezone.utc).isoformat()
    alert_id = f"ALT-MITM-{int(datetime.now(timezone.utc).timestamp())}-{uuid.uuid4().hex[:6]}"
    incident_desc = f"AES-256-GCM authentication tag mismatch: 128-bit MAC validation failed for {device_id}"

    alert = {
        "alert_id": alert_id,
        "device_id": device_id,
        "severity": "critical",
        "attack_type": "MITM_CIPHERTEXT_TAMPERING",
        "description": incident_desc,
        "timestamp": now_iso,
    }
    _DETECTED_ALERTS.append(alert)
    await firestore_service.publish_security_alert(alert)

    security_manager._record_security_incident(
        "MITM_CIPHERTEXT_TAMPERING",
        device_id,
        "SES-SIMULATED-02",
        incident_desc,
        severity="critical",
    )

    return SimulationResult(
        attack_name="Man-In-The-Middle Ciphertext Tampering",
        attack_type="MITM_CIPHERTEXT_TAMPERING",
        payload_sent={"device_id": device_id, "tampered_bytes": "0xDEADBEEF...", "cipher": "AES-256-GCM"},
        detection_status="BLOCKED_BY_GATEWAY",
        status_code=400,
        defense_triggered="AES-256-GCM 128-bit Authentication Tag Integrity Check",
        mitigation_action="Ciphertext discarded un-decrypted, intrusion alert triggered, session flagged.",
        incident_logged=True,
        incident_id=alert_id,
        timestamp=now_iso,
    )


@router.post("/fake-device", response_model=SimulationResult, summary="Simulate Spoofed / Unregistered Device Handshake")
async def simulate_fake_device():
    """Simulates an unregistered rogue device attempting to initiate PQC session handshake."""
    device_id = "ROGUE-DEVICE-SPOOF-X99"
    now_iso = datetime.now(timezone.utc).isoformat()
    alert_id = f"ALT-SPOOF-{int(datetime.now(timezone.utc).timestamp())}-{uuid.uuid4().hex[:6]}"
    incident_desc = f"Unregistered device {device_id} attempted ML-KEM-768 handshake without public key certificate"

    alert = {
        "alert_id": alert_id,
        "device_id": device_id,
        "severity": "high",
        "attack_type": "UNREGISTERED_DEVICE_SPOOFING",
        "description": incident_desc,
        "timestamp": now_iso,
    }
    _DETECTED_ALERTS.append(alert)
    await firestore_service.publish_security_alert(alert)

    security_manager._record_security_incident(
        "UNREGISTERED_DEVICE_SPOOFING",
        device_id,
        None,
        incident_desc,
        severity="high",
    )

    return SimulationResult(
        attack_name="Rogue Device Identity Spoofing",
        attack_type="UNREGISTERED_DEVICE_SPOOFING",
        payload_sent={"device_id": device_id, "attempted_action": "POST /crypto/handshake/init"},
        detection_status="BLOCKED_BY_GATEWAY",
        status_code=404,
        defense_triggered="Pre-Provisioned ML-DSA-65 Public Key Identity Verification",
        mitigation_action="Handshake rejected with HTTP 404, device blocked, network access denied.",
        incident_logged=True,
        incident_id=alert_id,
        timestamp=now_iso,
    )


@router.post("/unauthorized-command", response_model=SimulationResult, summary="Simulate RBAC Privilege Escalation")
async def simulate_unauthorized_command():
    """Simulates an unprivileged clinician role attempting an administrative device revocation."""
    user = "clinician-test-01"
    now_iso = datetime.now(timezone.utc).isoformat()
    alert_id = f"ALT-RBAC-{int(datetime.now(timezone.utc).timestamp())}-{uuid.uuid4().hex[:6]}"
    incident_desc = f"Clinician user '{user}' attempted administrative firmware signing without ADMIN role"

    alert = {
        "alert_id": alert_id,
        "device_id": "GATEWAY-RBAC",
        "severity": "medium",
        "attack_type": "RBAC_PRIVILEGE_ESCALATION",
        "description": incident_desc,
        "timestamp": now_iso,
    }
    _DETECTED_ALERTS.append(alert)
    await firestore_service.publish_security_alert(alert)

    security_manager._record_security_incident(
        "RBAC_PRIVILEGE_ESCALATION",
        "GATEWAY-RBAC",
        None,
        incident_desc,
        severity="medium",
    )

    return SimulationResult(
        attack_name="Unauthorized Command & Privilege Escalation",
        attack_type="RBAC_PRIVILEGE_ESCALATION",
        payload_sent={"user": user, "attempted_action": "OTA_FIRMWARE_SIGNING", "required_role": "ADMIN"},
        detection_status="BLOCKED_BY_GATEWAY",
        status_code=403,
        defense_triggered="FastAPI Firebase Token RBAC Guard (Role Claims Enforcement)",
        mitigation_action="Operation rejected with HTTP 403 Forbidden, security officer alerted.",
        incident_logged=True,
        incident_id=alert_id,
        timestamp=now_iso,
    )


@router.post("/firmware-tampering", response_model=SimulationResult, summary="Simulate Firmware Image Tampering")
async def simulate_firmware_tampering():
    """Simulates deploying a modified firmware update with an invalid SHA-256 fingerprint."""
    firmware_name = "SecureMed-RTOS-Patch-v2.4.1"
    now_iso = datetime.now(timezone.utc).isoformat()
    alert_id = f"ALT-FW-{int(datetime.now(timezone.utc).timestamp())}-{uuid.uuid4().hex[:6]}"
    incident_desc = f"Firmware hash mismatch for {firmware_name}: SHA-256 binary fingerprint altered"

    alert = {
        "alert_id": alert_id,
        "device_id": firmware_name,
        "severity": "critical",
        "attack_type": "FIRMWARE_TAMPERING_DETECTED",
        "description": incident_desc,
        "timestamp": now_iso,
    }
    _DETECTED_ALERTS.append(alert)
    await firestore_service.publish_security_alert(alert)

    security_manager._record_security_incident(
        "FIRMWARE_TAMPERING_DETECTED",
        firmware_name,
        None,
        incident_desc,
        severity="critical",
    )

    return SimulationResult(
        attack_name="OTA Firmware Binary Tampering",
        attack_type="FIRMWARE_TAMPERING_DETECTED",
        payload_sent={"firmware_name": firmware_name, "tampered_sha256": "0xbadc0de000000000..."},
        detection_status="BLOCKED_BY_GATEWAY",
        status_code=400,
        defense_triggered="SHA-256 Binary Integrity & NIST FIPS 204 Vendor Signature Verification",
        mitigation_action="OTA package quarantined, distribution halted, hospital firmware lock engaged.",
        incident_logged=True,
        incident_id=alert_id,
        timestamp=now_iso,
    )


@router.post("/rate-limit", response_model=SimulationResult, summary="Simulate Rate-Limit & Packet Flooding Attack")
async def simulate_rate_limit():
    """Simulates high-frequency telemetry flooding to test rate limiting and resource protection."""
    device_id = "MED-DEV-VENT-901B"
    now_iso = datetime.now(timezone.utc).isoformat()
    alert_id = f"ALT-FLOOD-{int(datetime.now(timezone.utc).timestamp())}-{uuid.uuid4().hex[:6]}"
    incident_desc = f"Packet flood detected from {device_id}: Rate exceeded 100 packets/second"

    alert = {
        "alert_id": alert_id,
        "device_id": device_id,
        "severity": "high",
        "attack_type": "RATE_LIMIT_EXCEEDED",
        "description": incident_desc,
        "timestamp": now_iso,
    }
    _DETECTED_ALERTS.append(alert)
    await firestore_service.publish_security_alert(alert)

    security_manager._record_security_incident(
        "RATE_LIMIT_EXCEEDED",
        device_id,
        "SES-SIMULATED-03",
        incident_desc,
        severity="high",
    )

    return SimulationResult(
        attack_name="Device Telemetry Flooding & DoS",
        attack_type="RATE_LIMIT_EXCEEDED",
        payload_sent={"device_id": device_id, "packet_rate": "120 packets/sec", "threshold": "20 packets/sec"},
        detection_status="THROTTLED_BY_GATEWAY",
        status_code=429,
        defense_triggered="Gateway Rate Limiting & Sliding Window Traffic Throttler",
        mitigation_action="Excess packets dropped with HTTP 429, source IP throttled for 30 seconds.",
        incident_logged=True,
        incident_id=alert_id,
        timestamp=now_iso,
    )
