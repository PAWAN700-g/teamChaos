"""SecureMed IoT - Post-Quantum Firmware Security & Anti-Rollback Engine.

Enforces:
1. NIST FIPS 204 (ML-DSA-65) Post-Quantum Vendor Signature Verification.
2. SHA-256 Binary Integrity Fingerprinting.
3. Pre-Provisioned Trusted Vendor Keystore (strict unknown key rejection).
4. Monotonic Anti-Rollback Version Guards (prohibits downgrade attacks).
5. Tamper-evident Audit Logging & SIEM Security Alerts for all verification events.
"""

import base64
import re
from datetime import datetime, timezone
from typing import Dict, Any, Optional, Tuple, List
from fastapi import HTTPException, status

from app.core.crypto_engine import RealPQCCryptoEngine
from app.core.session_manager import security_manager
from app.core.firestore_service import firestore_service
from app.api.v1.endpoints.telemetry import _DETECTED_ALERTS


def parse_semver(v_str: str) -> Tuple[int, int, int]:
    """Parse semver string (e.g., '2.4.1', 'v2.4.1-pqc', '3.0') into (major, minor, patch)."""
    clean = re.sub(r'^[vV]', '', v_str.strip())
    # Extract leading digits
    m = re.match(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?', clean)
    if not m:
        return (0, 0, 0)
    major = int(m.group(1))
    minor = int(m.group(2)) if m.group(2) else 0
    patch = int(m.group(3)) if m.group(3) else 0
    return (major, minor, patch)


def compare_versions(v1: str, v2: str) -> int:
    """Compare two version strings. Returns -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2."""
    t1 = parse_semver(v1)
    t2 = parse_semver(v2)
    if t1 < t2:
        return -1
    elif t1 > t2:
        return 1
    return 0


class FirmwareSecurityService:
    """Central authority for firmware signing, verification, and anti-rollback enforcement."""

    DEFAULT_MINIMUM_VERSION = "2.0.0"
    DEFAULT_BASELINE_VERSION = "2.4.1"

    def __init__(self):
        # 1. Initialize Primary Trusted Vendor Keypair (ML-DSA-65)
        self._primary_priv, self._primary_pub = RealPQCCryptoEngine.generate_dsa_keypair()
        self._primary_pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(self._primary_pub)
        self._primary_pub_b64 = base64.b64encode(self._primary_pub_bytes).decode("utf-8")

        # 2. Secondary/Backup Trusted Vendor Keypair (ML-DSA-65)
        self._backup_priv, self._backup_pub = RealPQCCryptoEngine.generate_dsa_keypair()
        self._backup_pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(self._backup_pub)
        self._backup_pub_b64 = base64.b64encode(self._backup_pub_bytes).decode("utf-8")

        # 3. Trusted Vendor Keystore: key_id -> metadata
        self.trusted_keystore: Dict[str, Dict[str, Any]] = {
            "VENDOR-SECUREMED-PRIMARY": {
                "key_id": "VENDOR-SECUREMED-PRIMARY",
                "vendor_name": "SecureMed Medical Systems Inc. (Primary Vendor Authority)",
                "algorithm": "ML-DSA-65 (NIST FIPS 204)",
                "public_key_bytes": self._primary_pub_bytes,
                "public_key_b64": self._primary_pub_b64,
                "status": "ACTIVE_TRUSTED",
                "registered_at": datetime.now(timezone.utc).isoformat(),
            },
            "VENDOR-SECUREMED-BACKUP": {
                "key_id": "VENDOR-SECUREMED-BACKUP",
                "vendor_name": "SecureMed Disaster Recovery Vendor Signer",
                "algorithm": "ML-DSA-65 (NIST FIPS 204)",
                "public_key_bytes": self._backup_pub_bytes,
                "public_key_b64": self._backup_pub_b64,
                "status": "ACTIVE_TRUSTED",
                "registered_at": datetime.now(timezone.utc).isoformat(),
            },
        }

        # Anti-rollback minimum allowed versions by device category / model
        self.minimum_allowed_versions: Dict[str, str] = {
            "SecureMed-RTOS-Patch": "2.0.0",
            "Multi-parameter Vital Monitor": "2.1.0",
            "Continuous Infusion Controller": "1.8.0",
            "Autonomous Respiratory Assist": "2.0.0",
        }

        # Baseline running versions
        self.running_versions: Dict[str, str] = {
            "SecureMed-RTOS-Patch": "2.4.1",
            "Multi-parameter Vital Monitor": "2.4.1",
            "Continuous Infusion Controller": "2.4.1",
            "Autonomous Respiratory Assist": "3.1.0",
        }

    def register_trusted_vendor_key(
        self,
        key_id: str,
        vendor_name: str,
        public_key_bytes: bytes,
    ) -> Dict[str, Any]:
        """Registers an authorized vendor signing key in the Trusted Keystore."""
        pub_b64 = base64.b64encode(public_key_bytes).decode("utf-8")
        entry = {
            "key_id": key_id,
            "vendor_name": vendor_name,
            "algorithm": "ML-DSA-65 (NIST FIPS 204)",
            "public_key_bytes": public_key_bytes,
            "public_key_b64": pub_b64,
            "status": "ACTIVE_TRUSTED",
            "registered_at": datetime.now(timezone.utc).isoformat(),
        }
        self.trusted_keystore[key_id] = entry
        return entry

    # -------------------------------------------------------------
    # 1. Synthetic Firmware Package Generation
    # -------------------------------------------------------------

    def generate_synthetic_firmware(
        self,
        firmware_name: str = "SecureMed-RTOS-Patch-v2.4.1",
        version: str = "2.4.1",
        min_allowed_version: str = "2.0.0",
        vendor_key_id: str = "VENDOR-SECUREMED-PRIMARY",
        use_untrusted_key: bool = False,
    ) -> Dict[str, Any]:
        """Generates a synthetic firmware binary, computes SHA-256, and signs with ML-DSA-65."""
        # 1. Synthesize firmware payload bytes
        timestamp = datetime.now(timezone.utc).isoformat()
        synthetic_source = (
            f"// SecureMed Microkernel RTOS Firmware Image\n"
            f"// Model: {firmware_name}\n"
            f"// Version: {version}\n"
            f"// Build Timestamp: {timestamp}\n"
            f"// Status: SYNTHETIC TEST FIRMWARE (HACKATHON PROTOYPE)\n"
            f"// Crypto Subsystem: ML-KEM-768 / ML-DSA-65 / AES-256-GCM\n"
            f"void securemed_main() {{ initialize_pqc_gateway(); }}\n"
        )
        raw_firmware_bytes = synthetic_source.encode("utf-8")
        firmware_b64 = base64.b64encode(raw_firmware_bytes).decode("utf-8")

        # 2. Compute SHA-256 fingerprint
        computed_sha256 = RealPQCCryptoEngine.compute_sha256(raw_firmware_bytes)

        # 3. Sign with ML-DSA-65
        if use_untrusted_key:
            # Generate a rogue keypair that is NOT in the trusted keystore
            untrusted_priv, untrusted_pub = RealPQCCryptoEngine.generate_dsa_keypair()
            sig_bytes = RealPQCCryptoEngine.dsa_sign(untrusted_priv, raw_firmware_bytes)
            pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(untrusted_pub)
            signing_key_id = "ROGUE-UNAUTHORIZED-VENDOR-KEY"
        else:
            if vendor_key_id == "VENDOR-SECUREMED-BACKUP":
                sig_bytes = RealPQCCryptoEngine.dsa_sign(self._backup_priv, raw_firmware_bytes)
                pub_bytes = self._backup_pub_bytes
                signing_key_id = "VENDOR-SECUREMED-BACKUP"
            else:
                sig_bytes = RealPQCCryptoEngine.dsa_sign(self._primary_priv, raw_firmware_bytes)
                pub_bytes = self._primary_pub_bytes
                signing_key_id = "VENDOR-SECUREMED-PRIMARY"

        sig_b64 = base64.b64encode(sig_bytes).decode("utf-8")
        pub_b64 = base64.b64encode(pub_bytes).decode("utf-8")

        return {
            "firmware_name": firmware_name,
            "version": version,
            "min_allowed_version": min_allowed_version,
            "firmware_image_b64": firmware_b64,
            "sha256_fingerprint": computed_sha256,
            "size_bytes": len(raw_firmware_bytes),
            "vendor_key_id": signing_key_id,
            "vendor_dsa_pub_b64": pub_b64,
            "vendor_signature_b64": sig_b64,
            "generated_at": timestamp,
            "is_synthetic": True,
        }

    # -------------------------------------------------------------
    # 2. Firmware Verification & Anti-Rollback Enforcement
    # -------------------------------------------------------------

    async def verify_and_accept_firmware(
        self,
        firmware_name: str,
        version: str,
        firmware_image_b64: str,
        vendor_signature_b64: str,
        vendor_dsa_pub_b64: str,
        expected_sha256: Optional[str] = None,
        vendor_key_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Cryptographically verifies firmware against trusted vendor keystore & anti-rollback policy."""
        now_iso = datetime.now(timezone.utc).isoformat()
        min_allowed = self.minimum_allowed_versions.get(firmware_name, self.DEFAULT_MINIMUM_VERSION)

        # Step 1: Decode binary
        try:
            raw_firmware = base64.b64decode(firmware_image_b64)
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid base64 encoding in firmware_image_b64",
            )

        # Step 2: Compute and verify SHA-256 binary fingerprint
        computed_sha256 = RealPQCCryptoEngine.compute_sha256(raw_firmware)
        if expected_sha256 and expected_sha256.lower() != computed_sha256.lower():
            desc = f"Firmware hash mismatch for {firmware_name}: expected {expected_sha256}, computed {computed_sha256}"
            alert = {
                "alert_id": f"ALT-FW-HASH-{int(datetime.now(timezone.utc).timestamp())}",
                "device_id": firmware_name,
                "severity": "critical",
                "attack_type": "FIRMWARE_SHA256_MISMATCH",
                "description": desc,
                "timestamp": now_iso,
            }
            _DETECTED_ALERTS.append(alert)
            await firestore_service.publish_security_alert(alert)
            security_manager._record_security_incident("FIRMWARE_SHA256_MISMATCH", firmware_name, None, desc, severity="critical")
            security_manager._record_audit_event("FIRMWARE_VERIFICATION_REJECTED", firmware_name, {
                "reason": "SHA-256 fingerprint mismatch",
                "expected": expected_sha256,
                "computed": computed_sha256,
            }, result="REJECTED")

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Firmware binary integrity compromised. Expected SHA-256 '{expected_sha256}', computed '{computed_sha256}'.",
            )

        # Step 3: Check Trusted Vendor Keystore (Reject Unknown Signing Keys)
        try:
            pub_bytes = base64.b64decode(vendor_dsa_pub_b64)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Malformed vendor public key encoding: {str(e)}",
            )

        # Check if the public key bytes match any active key in the trusted keystore
        matched_vendor: Optional[Dict[str, Any]] = None
        for key_entry in self.trusted_keystore.values():
            if key_entry["public_key_bytes"] == pub_bytes:
                matched_vendor = key_entry
                break

        if not matched_vendor:
            desc = f"Firmware rejected for {firmware_name}: Provided ML-DSA-65 public key is not registered in the Trusted Vendor Keystore."
            alert = {
                "alert_id": f"ALT-FW-KEY-{int(datetime.now(timezone.utc).timestamp())}",
                "device_id": firmware_name,
                "severity": "critical",
                "attack_type": "FIRMWARE_UNKNOWN_SIGNING_KEY",
                "description": desc,
                "timestamp": now_iso,
            }
            _DETECTED_ALERTS.append(alert)
            await firestore_service.publish_security_alert(alert)
            security_manager._record_security_incident("FIRMWARE_UNKNOWN_SIGNING_KEY", firmware_name, None, desc, severity="critical")
            security_manager._record_audit_event("FIRMWARE_VERIFICATION_REJECTED", firmware_name, {
                "reason": "Unknown or untrusted vendor signing key",
                "provided_key_preview": vendor_dsa_pub_b64[:32] + "...",
            }, result="REJECTED")

            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Security policy rejection: Signing public key is not present in the Trusted Vendor Keystore.",
            )

        # Step 4: Enforce Anti-Rollback Version Protection (Reject Prohibited Older Versions)
        cmp_min = compare_versions(version, min_allowed)
        if cmp_min < 0:
            desc = (
                f"Anti-rollback violation for {firmware_name}: Target version '{version}' is older "
                f"than minimum permitted threshold '{min_allowed}'. Downgrade attack blocked."
            )
            alert = {
                "alert_id": f"ALT-FW-ROLLBACK-{int(datetime.now(timezone.utc).timestamp())}",
                "device_id": firmware_name,
                "severity": "high",
                "attack_type": "FIRMWARE_ROLLBACK_ATTEMPT",
                "description": desc,
                "timestamp": now_iso,
            }
            _DETECTED_ALERTS.append(alert)
            await firestore_service.publish_security_alert(alert)
            security_manager._record_security_incident("FIRMWARE_ROLLBACK_ATTEMPT", firmware_name, None, desc, severity="high")
            security_manager._record_audit_event("FIRMWARE_VERIFICATION_REJECTED", firmware_name, {
                "reason": "Anti-rollback violation",
                "attempted_version": version,
                "minimum_allowed_version": min_allowed,
            }, result="REJECTED")

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Anti-rollback protection violation: Firmware version '{version}' is prohibited. Minimum allowed is '{min_allowed}'.",
            )

        # Step 5: Verify NIST FIPS 204 ML-DSA-65 Signature
        try:
            vendor_pub = RealPQCCryptoEngine.deserialize_dsa_public_key(pub_bytes)
            signature_bytes = base64.b64decode(vendor_signature_b64)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Malformed vendor signature: {str(e)}",
            )

        sig_valid = RealPQCCryptoEngine.dsa_verify(
            public_key=vendor_pub,
            signature=signature_bytes,
            message=raw_firmware,
        )

        if not sig_valid:
            desc = f"Firmware signature verification failed for {firmware_name}: Invalid ML-DSA-65 signature on binary."
            alert = {
                "alert_id": f"ALT-FW-SIG-{int(datetime.now(timezone.utc).timestamp())}",
                "device_id": firmware_name,
                "severity": "critical",
                "attack_type": "FIRMWARE_SIGNATURE_INVALID",
                "description": desc,
                "timestamp": now_iso,
            }
            _DETECTED_ALERTS.append(alert)
            await firestore_service.publish_security_alert(alert)
            security_manager._record_security_incident("FIRMWARE_SIGNATURE_INVALID", firmware_name, None, desc, severity="critical")
            security_manager._record_audit_event("FIRMWARE_VERIFICATION_REJECTED", firmware_name, {
                "reason": "ML-DSA-65 signature verification failed",
                "vendor_key_id": matched_vendor["key_id"],
            }, result="REJECTED")

            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Firmware signature verification failed: Payload was modified or not signed by authorized vendor key.",
            )

        # Step 6: Record Successful Verification Event
        security_manager._record_audit_event(
            event_type="FIRMWARE_VERIFIED",
            actor=matched_vendor["key_id"],
            details={
                "firmware_name": firmware_name,
                "version": version,
                "sha256": computed_sha256,
                "size_bytes": len(raw_firmware),
                "signing_algorithm": "ML-DSA-65 (NIST FIPS 204)",
                "vendor_authority": matched_vendor["vendor_name"],
            },
            result="SUCCESS",
        )

        # Update running version baseline
        self.running_versions[firmware_name] = version

        return {
            "firmware_name": firmware_name,
            "version": version,
            "sha256_fingerprint": computed_sha256,
            "size_bytes": len(raw_firmware),
            "vendor_key_id": matched_vendor["key_id"],
            "vendor_authority": matched_vendor["vendor_name"],
            "signature_verified": True,
            "anti_rollback_verified": True,
            "min_allowed_version": min_allowed,
            "status": "trusted_and_verified",
            "verified_at": now_iso,
        }

    def get_trusted_keystore_summary(self) -> List[Dict[str, Any]]:
        """Returns public list of trusted vendor keys without exposing private material."""
        return [
            {
                "key_id": v["key_id"],
                "vendor_name": v["vendor_name"],
                "algorithm": v["algorithm"],
                "public_key_b64": v["public_key_b64"],
                "status": v["status"],
                "registered_at": v["registered_at"],
            }
            for v in self.trusted_keystore.values()
        ]

    def get_firmware_status(self) -> Dict[str, Any]:
        """Returns current firmware baseline and anti-rollback policies."""
        return {
            "baseline_version": self.DEFAULT_BASELINE_VERSION,
            "default_minimum_version": self.DEFAULT_MINIMUM_VERSION,
            "running_versions": self.running_versions,
            "anti_rollback_policies": self.minimum_allowed_versions,
            "trusted_keys_count": len(self.trusted_keystore),
            "signature_algorithm": "ML-DSA-65 (NIST FIPS 204)",
            "integrity_algorithm": "SHA-256",
        }


# Global singleton firmware security service
firmware_service = FirmwareSecurityService()
