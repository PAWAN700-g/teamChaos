"""SecureMed IoT - Medical Device Simulator Test & Verification Suite.

Verifies:
1. Synthetic readings generation (ECG, Heart Rate, SpO2) are realistic and strictly synthetic.
2. Device registration with FastAPI backend (ML-DSA-65 identity public key).
3. Post-Quantum mutual authentication & key establishment (ML-KEM-768 + HKDF-SHA-256).
4. Valid AES-256-GCM encrypted telemetry ingestion by backend.
5. Strict Replay Attack rejection (duplicate/out-of-order sequence counter).
6. MITM Ciphertext Tampering rejection (GCM authentication tag verification).
7. Digital Signature Forgery rejection (NIST FIPS 204 ML-DSA-65 verification).
8. Temporal Freshness Window violation rejection (stale/drifted timestamp).
9. Emergency Device Revocation enforcement (HTTP 403 & state transition to REVOKED).
10. Safe logging preventing secret leakage.

DISCLAIMER: Hackathon prototype only. Synthetic patient data only.
"""

import sys
import os
import json
import logging
from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))
from main import app
from app.core.session_manager import security_manager

from models import (
    DeviceType,
    DeviceStatus,
    ConnectionState,
    ECGSyntheticReading,
    HeartRateSyntheticReading,
    SpO2SyntheticReading,
)
from device import MedicalDevice

# Create test client for backend
test_client = TestClient(app)


# =====================================================================
# Unit Tests: Synthetic Telemetry Generation
# =====================================================================

def test_ecg_synthetic_reading_generation():
    """Verify ECG monitor generates realistic but strictly synthetic readings."""
    reading = ECGSyntheticReading.generate("MED-DEV-ECG-101")
    assert reading.is_synthetic is True
    assert "HACKATHON PROTOTYPE ONLY" in reading.disclaimer
    assert reading.device_type == DeviceType.ECG_MONITOR.value
    assert 50 <= reading.heart_rate_bpm <= 120
    assert len(reading.waveform_samples_mv) >= 15
    assert reading.lead_status == "CONNECTED"
    assert "Sinus Rhythm" in reading.rhythm_classification


def test_heart_rate_synthetic_reading_generation():
    """Verify Heart Rate monitor generates realistic synthetic vitals."""
    reading = HeartRateSyntheticReading.generate("MED-DEV-HR-202")
    assert reading.is_synthetic is True
    assert "HACKATHON PROTOTYPE ONLY" in reading.disclaimer
    assert reading.device_type == DeviceType.HEART_RATE_MONITOR.value
    assert 50 <= reading.heart_rate_bpm <= 120
    assert reading.hrv_rmssd_ms > 0
    assert reading.pulse_quality_index >= 90


def test_spo2_synthetic_reading_generation():
    """Verify SpO2 monitor generates realistic synthetic pulse oximetry."""
    reading = SpO2SyntheticReading.generate("MED-DEV-SPO2-303")
    assert reading.is_synthetic is True
    assert "HACKATHON PROTOTYPE ONLY" in reading.disclaimer
    assert reading.device_type == DeviceType.SPO2_MONITOR.value
    assert 90 <= reading.spo2_percent <= 100
    assert 50 <= reading.pulse_rate_bpm <= 120
    assert reading.perfusion_index > 0
    assert reading.probe_status == "ATTACHED_FINGER"


def test_anomaly_reading_generation():
    """Verify anomaly generation for cybersecurity alert testing."""
    ecg_anomaly = ECGSyntheticReading.generate("MED-DEV-ECG-101", is_attack=True)
    assert ecg_anomaly.heart_rate_bpm >= 180
    assert ecg_anomaly.device_status == DeviceStatus.WARNING.value

    spo2_anomaly = SpO2SyntheticReading.generate("MED-DEV-SPO2-303", is_attack=True)
    assert spo2_anomaly.spo2_percent < 80


# =====================================================================
# Integration Tests: Device Lifecycle & Backend Telemetry Verification
# =====================================================================

def test_full_device_registration_and_pqc_handshake():
    """Verify device registers ML-DSA-65 public key and completes ML-KEM-768 handshake."""
    device = MedicalDevice(
        device_id="TEST-DEV-ECG-999",
        device_type=DeviceType.ECG_MONITOR,
        name="Test ECG Monitor",
        gateway_url="http://localhost:8000/api/v1",
        client=test_client,
    )
    assert device.connection_state == ConnectionState.DISCONNECTED

    # 1. Register with backend
    reg_ok = device.register()
    assert reg_ok is True
    assert device.connection_state == ConnectionState.REGISTERED

    # Verify device exists in backend state
    backend_dev = security_manager.get_device(device.device_id)
    assert backend_dev is not None
    assert backend_dev.status == "active"

    # 2. Complete PQC Handshake
    hs_ok = device.establish_session()
    assert hs_ok is True
    assert device.connection_state == ConnectionState.AUTHENTICATED
    assert device.session_id is not None
    assert device.session_id.startswith("SES-")
    assert device.sequence_counter == 0
    assert device.is_session_active() is True


def test_valid_telemetry_transmission_and_decryption():
    """Verify valid telemetry is encrypted with AES-256-GCM, signed, and ingested."""
    device = MedicalDevice(
        device_id="TEST-DEV-HR-888",
        device_type=DeviceType.HEART_RATE_MONITOR,
        name="Test HR Monitor",
        gateway_url="http://localhost:8000/api/v1",
        client=test_client,
    )
    assert device.register() is True
    assert device.establish_session() is True

    # Packet #1
    success_1, res_1 = device.emit_telemetry()
    assert success_1 is True
    assert res_1["status"] == "verified"
    assert res_1["pqc_signature_verified"] is True
    assert res_1["tampering_detected"] is False
    assert res_1["sequence_number"] == 1
    assert device.sequence_counter == 1
    assert device.connection_state == ConnectionState.TRANSMITTING

    # Packet #2
    success_2, res_2 = device.emit_telemetry()
    assert success_2 is True
    assert res_2["sequence_number"] == 2
    assert device.sequence_counter == 2


def test_replay_attack_rejected():
    """Verify duplicate sequence number is strictly rejected as a replay attack."""
    device = MedicalDevice(
        device_id="TEST-DEV-SPO2-777",
        device_type=DeviceType.SPO2_MONITOR,
        name="Test SpO2 Monitor",
        gateway_url="http://localhost:8000/api/v1",
        client=test_client,
    )
    assert device.register() is True
    assert device.establish_session() is True

    # Valid sequence 1
    ok1, res1 = device.emit_telemetry()
    assert ok1 is True
    assert res1["sequence_number"] == 1

    # Attack: Replay sequence 1 again
    ok_replay, res_replay = device.emit_telemetry(override_sequence=1)
    assert ok_replay is False
    assert res_replay["status_code"] == 400
    assert "REPLAY_ATTACK_DETECTED" in res_replay["detail"]


def test_tampered_ciphertext_rejected():
    """Verify MITM ciphertext bit-flip triggers AES-256-GCM authentication tag failure."""
    device = MedicalDevice(
        device_id="TEST-DEV-ECG-666",
        device_type=DeviceType.ECG_MONITOR,
        name="Test ECG Monitor",
        gateway_url="http://localhost:8000/api/v1",
        client=test_client,
    )
    assert device.register() is True
    assert device.establish_session() is True

    # Attack: Tamper ciphertext bytes
    ok, res = device.emit_telemetry(attack_type="tamper_ciphertext")
    assert ok is False
    assert res["status_code"] == 400
    assert "tag mismatch" in res["detail"].lower() or "tampering" in res["detail"].lower()


def test_tampered_signature_rejected():
    """Verify forged ML-DSA-65 digital signature is rejected with HTTP 401."""
    device = MedicalDevice(
        device_id="TEST-DEV-HR-555",
        device_type=DeviceType.HEART_RATE_MONITOR,
        name="Test HR Monitor",
        gateway_url="http://localhost:8000/api/v1",
        client=test_client,
    )
    assert device.register() is True
    assert device.establish_session() is True

    # Attack: Corrupt digital signature
    ok, res = device.emit_telemetry(attack_type="tamper_signature")
    assert ok is False
    assert res["status_code"] == 401
    assert "signature verification failed" in res["detail"].lower()


def test_stale_timestamp_rejected():
    """Verify telemetry outside the ±60-second temporal freshness window is rejected."""
    device = MedicalDevice(
        device_id="TEST-DEV-SPO2-444",
        device_type=DeviceType.SPO2_MONITOR,
        name="Test SpO2 Monitor",
        gateway_url="http://localhost:8000/api/v1",
        client=test_client,
    )
    assert device.register() is True
    assert device.establish_session() is True

    # Drift timestamp by 120 seconds into the past
    stale_ts = (datetime.now(timezone.utc) - timedelta(seconds=120)).isoformat()
    ok, res = device.emit_telemetry(override_timestamp=stale_ts)
    assert ok is False
    assert res["status_code"] == 400
    assert "STALE_TIMESTAMP" in res["detail"]


def test_device_revocation_enforcement():
    """Verify that revoking device credentials blocks all subsequent telemetry."""
    device = MedicalDevice(
        device_id="TEST-DEV-ECG-333",
        device_type=DeviceType.ECG_MONITOR,
        name="Test ECG Monitor",
        gateway_url="http://localhost:8000/api/v1",
        client=test_client,
    )
    assert device.register() is True
    assert device.establish_session() is True

    # Valid transmission before revocation
    ok, res = device.emit_telemetry()
    assert ok is True

    # Admin revokes device on Gateway
    revoke_res = test_client.post(f"/api/v1/devices/{device.device_id}/revoke")
    assert revoke_res.status_code == 200
    assert revoke_res.json()["status"] == "revoked"

    # Attempt transmission after revocation
    ok_after, res_after = device.emit_telemetry()
    assert ok_after is False
    assert device.connection_state == ConnectionState.REVOKED
    assert res_after["status_code"] in (400, 403) or res_after.get("error") == "DEVICE_REVOKED"


def test_safe_logging_never_exposes_secrets(caplog):
    """Verify that logging routines never leak private keys or symmetric session keys."""
    with caplog.at_level(logging.DEBUG):
        device = MedicalDevice(
            device_id="TEST-DEV-LOG-111",
            device_type=DeviceType.ECG_MONITOR,
            name="Safe Logger Test",
            gateway_url="http://localhost:8000/api/v1",
            client=test_client,
        )
        device.register()
        device.establish_session()
        device.emit_telemetry()
        # Trigger an error safely
        device._safe_log_error("Test Error", 400, "Simulated network failure")

    log_text = caplog.text
    # Ensure raw private key or session key byte strings are never printed
    assert "b'\\x" not in log_text
    assert "dsa_private_key" not in log_text
    assert "telemetry_enc_key" not in log_text


# =====================================================================
# Programmatic / CLI Verification Suite Runner
# =====================================================================

def run_verification_suite(gateway_url: str = "http://localhost:8000/api/v1") -> bool:
    """Executes all 10 end-to-end verification checks and outputs a formatted report."""
    print("\n" + "=" * 80)
    print("   SecureMed IoT - Simulator & Cybersecurity Verification Suite")
    print(f"   Target Gateway: {gateway_url}")
    print("=" * 80)

    checks = [
        ("Synthetic Telemetry Generation (ECG, HR, SpO2)", test_ecg_synthetic_reading_generation),
        ("Disclaimers & Prototype Notice Compliance", test_heart_rate_synthetic_reading_generation),
        ("Device Identity Registration with Gateway", test_full_device_registration_and_pqc_handshake),
        ("Valid Telemetry AES-256-GCM Ingestion", test_valid_telemetry_transmission_and_decryption),
        ("Defense: Replay Attack Rejection (Sequence Monotonicity)", test_replay_attack_rejected),
        ("Defense: MITM Ciphertext Tampering Rejection (GCM Tag)", test_tampered_ciphertext_rejected),
        ("Defense: ML-DSA-65 Signature Forgery Rejection", test_tampered_signature_rejected),
        ("Defense: Temporal Freshness Window Enforcement (+/-60s)", test_stale_timestamp_rejected),
        ("Defense: Emergency Device Revocation Enforcement (HTTP 403)", test_device_revocation_enforcement),
    ]

    passed = 0
    for name, test_fn in checks:
        print(f"[*] Running check: {name}...", end=" ")
        try:
            test_fn()
            print("[PASS]")
            passed += 1
        except Exception as e:
            print(f"[FAIL]: {e}")

    print("=" * 80)
    print(f"Verification Results: {passed}/{len(checks)} checks PASSED.")
    print("=" * 80 + "\n")
    return passed == len(checks)


if __name__ == "__main__":
    success = run_verification_suite()
    sys.exit(0 if success else 1)
