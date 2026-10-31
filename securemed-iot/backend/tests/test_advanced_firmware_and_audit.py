"""SecureMed IoT - Advanced Firmware Security & Audit Logging Test Suite.

Automated tests for:
1. FIRMWARE SECURITY:
   - Synthetic test firmware package generation.
   - SHA-256 fingerprinting.
   - ML-DSA-65 post-quantum digital signature.
   - Pre-provisioned Trusted Vendor Keystore lookup.
   - Acceptance of authentic firmware.
   - Rejection of modified firmware (hash mismatch).
   - Rejection of unknown / untrusted vendor signing keys.
   - Anti-rollback version protection (prohibits downgrade attacks).
   - Tamper-evident verification audit trail.
2. AUDIT LOGGING:
   - Event ID, actor, event type, result, and timestamp schema validation.
   - Monotonic SHA-256 cryptographic hash-chaining.
   - Audit chain verification endpoint (`GET /api/v1/audit/verify`).
   - Detection and diagnostic isolation of tampered blocks.
   - External anchoring digest export (`GET /api/v1/audit/anchor`).
   - Restriction against direct client audit writes.
   - Disclosure of hash-chain limitation regarding whole-database rewriting.
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
from app.core.firmware_service import firmware_service

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_state():
    """Ensure clean gateway security manager state before each test."""
    security_manager.seed_default_devices()
    yield


# ==============================================================================
# 1. FIRMWARE SECURITY MODULE TESTS
# ==============================================================================

def test_generate_synthetic_firmware_package():
    """Requirement 1, 2, 3: Generate synthetic firmware, calculate SHA-256, and sign with ML-DSA-65."""
    res = client.post(
        "/api/v1/firmware/generate-synthetic",
        json={
            "firmware_name": "SecureMed-RTOS-Patch-v2.5.0",
            "version": "2.5.0",
            "min_allowed_version": "2.0.0",
            "vendor_key_id": "VENDOR-SECUREMED-PRIMARY",
        },
    )
    assert res.status_code == 200
    pkg = res.json()

    assert pkg["firmware_name"] == "SecureMed-RTOS-Patch-v2.5.0"
    assert pkg["version"] == "2.5.0"
    assert pkg["min_allowed_version"] == "2.0.0"
    assert "firmware_image_b64" in pkg
    assert "sha256_fingerprint" in pkg
    assert len(pkg["sha256_fingerprint"]) == 64
    assert pkg["vendor_key_id"] == "VENDOR-SECUREMED-PRIMARY"
    assert "vendor_dsa_pub_b64" in pkg
    assert "vendor_signature_b64" in pkg
    assert pkg["is_synthetic"] is True

    # Validate raw image matches calculated SHA-256
    raw_img = base64.b64decode(pkg["firmware_image_b64"])
    expected_sha = RealPQCCryptoEngine.compute_sha256(raw_img)
    assert pkg["sha256_fingerprint"] == expected_sha


def test_firmware_signature_verification_acceptance():
    """Requirement 4, 5, 9: Store trusted key, verify signature before acceptance, record verification event."""
    initial_audit_len = len(security_manager.audit_log_chain)

    # 1. Generate package signed by primary trusted vendor
    pkg = firmware_service.generate_synthetic_firmware(
        firmware_name="SecureMed-RTOS-Patch-v2.5.0",
        version="2.5.0",
        min_allowed_version="2.0.0",
        vendor_key_id="VENDOR-SECUREMED-PRIMARY",
    )

    # 2. Verify and accept firmware
    res = client.post(
        "/api/v1/firmware/verify",
        json={
            "firmware_name": pkg["firmware_name"],
            "version": pkg["version"],
            "firmware_image_b64": pkg["firmware_image_b64"],
            "vendor_signature_b64": pkg["vendor_signature_b64"],
            "vendor_dsa_pub_b64": pkg["vendor_dsa_pub_b64"],
            "expected_sha256": pkg["sha256_fingerprint"],
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["signature_verified"] is True
    assert data["anti_rollback_verified"] is True
    assert data["status"] == "trusted_and_verified"
    assert data["vendor_key_id"] == "VENDOR-SECUREMED-PRIMARY"

    # Verify audit event was appended
    assert len(security_manager.audit_log_chain) > initial_audit_len
    latest_evt = security_manager.audit_log_chain[-1]
    assert latest_evt["event_type"] == "FIRMWARE_VERIFIED"
    assert latest_evt["result"] == "SUCCESS"
    assert latest_evt["actor"] == "VENDOR-SECUREMED-PRIMARY"


def test_firmware_rejection_modified_binary():
    """Requirement 6: Reject modified firmware (altered SHA-256 / broken signature)."""
    pkg = firmware_service.generate_synthetic_firmware(
        firmware_name="SecureMed-RTOS-Patch-v2.5.0",
        version="2.5.0",
    )

    # Modify 1 byte of the binary image
    raw = base64.b64decode(pkg["firmware_image_b64"])
    tampered_bytes = raw + b"// TAMPERED_INJECTION_BACKDOOR"
    tampered_b64 = base64.b64encode(tampered_bytes).decode("utf-8")

    # 1. Mismatched SHA-256 check
    res_hash_fail = client.post(
        "/api/v1/firmware/verify",
        json={
            "firmware_name": pkg["firmware_name"],
            "version": pkg["version"],
            "firmware_image_b64": tampered_b64,
            "vendor_signature_b64": pkg["vendor_signature_b64"],
            "vendor_dsa_pub_b64": pkg["vendor_dsa_pub_b64"],
            "expected_sha256": pkg["sha256_fingerprint"],  # original sha
        },
    )
    assert res_hash_fail.status_code == 400
    assert "integrity compromised" in res_hash_fail.json()["detail"].lower()

    # 2. Signature verification check fails even if expected_sha256 omitted
    res_sig_fail = client.post(
        "/api/v1/firmware/verify",
        json={
            "firmware_name": pkg["firmware_name"],
            "version": pkg["version"],
            "firmware_image_b64": tampered_b64,
            "vendor_signature_b64": pkg["vendor_signature_b64"],
            "vendor_dsa_pub_b64": pkg["vendor_dsa_pub_b64"],
        },
    )
    assert res_sig_fail.status_code == 401
    assert "signature verification failed" in res_sig_fail.json()["detail"].lower()


def test_firmware_rejection_unknown_signing_key():
    """Requirement 7: Reject unknown signing keys not present in Trusted Vendor Keystore."""
    # Generate package signed by an untrusted rogue ML-DSA-65 keypair
    rogue_pkg = firmware_service.generate_synthetic_firmware(
        firmware_name="SecureMed-RTOS-Patch-v2.5.0",
        version="2.5.0",
        use_untrusted_key=True,
    )

    res = client.post(
        "/api/v1/firmware/verify",
        json={
            "firmware_name": rogue_pkg["firmware_name"],
            "version": rogue_pkg["version"],
            "firmware_image_b64": rogue_pkg["firmware_image_b64"],
            "vendor_signature_b64": rogue_pkg["vendor_signature_b64"],
            "vendor_dsa_pub_b64": rogue_pkg["vendor_dsa_pub_b64"],
        },
    )
    assert res.status_code == 403
    assert "trusted vendor keystore" in res.json()["detail"].lower()


def test_firmware_anti_rollback_enforcement():
    """Requirement 8: Reject prohibited older versions (Anti-Rollback Protection)."""
    # Attempt to submit an older prohibited version (1.5.0 < min_allowed: 2.0.0)
    prohibited_pkg = firmware_service.generate_synthetic_firmware(
        firmware_name="SecureMed-RTOS-Patch-v1.5.0",
        version="1.5.0",
        min_allowed_version="2.0.0",
        vendor_key_id="VENDOR-SECUREMED-PRIMARY",
    )

    res = client.post(
        "/api/v1/firmware/verify",
        json={
            "firmware_name": prohibited_pkg["firmware_name"],
            "version": prohibited_pkg["version"],
            "firmware_image_b64": prohibited_pkg["firmware_image_b64"],
            "vendor_signature_b64": prohibited_pkg["vendor_signature_b64"],
            "vendor_dsa_pub_b64": prohibited_pkg["vendor_dsa_pub_b64"],
        },
    )
    assert res.status_code == 400
    assert "anti-rollback" in res.json()["detail"].lower()
    assert "prohibited" in res.json()["detail"].lower()


def test_firmware_status_and_keystore_endpoints():
    """Verify firmware status, baseline versions, and public trusted keystore list."""
    res_status = client.get("/api/v1/firmware/status")
    assert res_status.status_code == 200
    st = res_status.json()
    assert "baseline_version" in st
    assert "anti_rollback_policies" in st
    assert st["signature_algorithm"] == "ML-DSA-65 (NIST FIPS 204)"

    res_keys = client.get("/api/v1/firmware/trusted-keys")
    assert res_keys.status_code == 200
    kd = res_keys.json()
    assert "trusted_keys" in kd
    assert len(kd["trusted_keys"]) >= 2
    key_ids = [k["key_id"] for k in kd["trusted_keys"]]
    assert "VENDOR-SECUREMED-PRIMARY" in key_ids


# ==============================================================================
# 2. AUDIT LOGGING MODULE TESTS
# ==============================================================================

def test_audit_event_schema_and_chaining():
    """Requirement 1, 2, 3, 4: Record security event with ID, actor, type, result, timestamp, and SHA-256 hash."""
    evt = security_manager._record_audit_event(
        event_type="DIAGNOSTIC_SECURITY_TEST",
        device_id="MED-DEV-TEST-001",
        details={"test_metric": 100, "status": "active"},
        actor="clinician@hospital.local",
        result="SUCCESS",
    )

    assert "event_id" in evt and evt["event_id"].startswith("EVT-")
    assert "timestamp" in evt
    assert evt["actor"] == "clinician@hospital.local"
    assert evt["event_type"] == "DIAGNOSTIC_SECURITY_TEST"
    assert evt["result"] == "SUCCESS"
    assert "previous_hash" in evt
    assert "entry_hash" in evt
    assert len(evt["entry_hash"]) == 64


def test_audit_chain_verification_endpoint_intact():
    """Requirement 5: Chain verification endpoint returns intact status and limitation disclosure."""
    res = client.get("/api/v1/audit/verify")
    assert res.status_code == 200
    data = res.json()

    assert data["is_intact"] is True
    assert data["total_blocks_verified"] >= 1
    assert data["head_hash"] == security_manager.audit_head_hash
    assert data["corrupted_block"] is None
    assert "verified" in data["message"].lower()

    # Verify requirement: document limitation regarding whole-database rewriting
    assert "limitation_disclosure" in data
    assert "database-level write access" in data["limitation_disclosure"].lower() or "whole-database" in data["limitation_disclosure"].lower()


def test_audit_tampering_detection():
    """Requirement 6: Detect modified records and report exact corrupted block."""
    assert len(security_manager.audit_log_chain) >= 1

    # Temporarily alter an audit block's payload
    target = security_manager.audit_log_chain[-1]
    orig_actor = target["actor"]
    target["actor"] = "MALICIOUS_IMPOSTOR"

    # Call verification endpoint
    res = client.get("/api/v1/audit/verify")
    assert res.status_code == 200
    data = res.json()

    assert data["is_intact"] is False
    assert data["corrupted_block"] is not None
    assert data["corrupted_block"]["block_index"] == target["index"]
    assert "mismatch" in data["corrupted_block"]["reason"].lower()

    # Restore actor to restore ledger validity
    target["actor"] = orig_actor
    res_restored = client.get("/api/v1/audit/verify")
    assert res_restored.json()["is_intact"] is True


def test_audit_external_anchoring_export():
    """Requirement 8: Export latest head hash & anchoring digest for external anchoring."""
    res = client.get("/api/v1/audit/anchor")
    assert res.status_code == 200
    anchor = res.json()

    assert "audit_head_hash" in anchor
    assert "chain_length" in anchor
    assert "latest_event_id" in anchor
    assert "anchoring_digest" in anchor
    assert len(anchor["anchoring_digest"]) == 64
    assert "limitation_disclosure" in anchor
    assert "external immutable authority" in anchor["limitation_disclosure"].lower()


def test_audit_write_restricted():
    """Requirement 7: Restrict audit write operations (clients cannot POST/PUT/DELETE audit logs)."""
    # POST to /audit/ledger should be 405 Method Not Allowed (only GET allowed)
    res_post = client.post("/api/v1/audit/ledger", json={"event": "FAKE_EVENT"})
    assert res_post.status_code == 405

    # DELETE to /audit/ledger should be 405 Method Not Allowed
    res_del = client.delete("/api/v1/audit/ledger")
    assert res_del.status_code == 405
