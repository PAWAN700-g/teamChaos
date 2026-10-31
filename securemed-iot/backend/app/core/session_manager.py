"""SecureMed IoT - Device Credential, Session Lifecycle, and Replay Manager.

Enforces:
1. Device identity credential registration & revocation.
2. ML-KEM-768 session lifecycle binding & TTL expiration.
3. Monotonic sequence number replay protection.
4. Cryptographic nonce-reuse prevention.
5. Strict temporal freshness window verification.
"""

from typing import Dict, Any, Optional, Set, List, Tuple
from datetime import datetime, timezone, timedelta
import uuid
import base64
import hashlib

from cryptography.hazmat.primitives.asymmetric import mldsa
from app.core.crypto_engine import RealPQCCryptoEngine


class DeviceRecord:
    def __init__(
        self,
        device_id: str,
        device_type: str,
        dsa_public_key: mldsa.MLDSA65PublicKey,
        dsa_pub_bytes: bytes,
        status: str = "active",
    ):
        self.device_id = device_id
        self.device_type = device_type
        self.dsa_public_key = dsa_public_key
        self.dsa_pub_bytes = dsa_pub_bytes
        self.status = status  # 'active' or 'revoked'
        self.registered_at = datetime.now(timezone.utc)
        self.revoked_at: Optional[datetime] = None

    @property
    def is_revoked(self) -> bool:
        return self.status == "revoked"

    def revoke(self):
        self.status = "revoked"
        self.revoked_at = datetime.now(timezone.utc)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "device_id": self.device_id,
            "device_type": self.device_type,
            "status": self.status,
            "is_pqc_secured": True,
            "dsa_public_key_b64": base64.b64encode(self.dsa_pub_bytes).decode("utf-8"),
            "registered_at": self.registered_at.isoformat(),
            "revoked_at": self.revoked_at.isoformat() if self.revoked_at else None,
        }


class SecureSession:
    def __init__(
        self,
        session_id: str,
        device_id: str,
        telemetry_enc_key: bytes,
        telemetry_mac_key: bytes,
        handshake_transcript: str,
        ttl_seconds: int = 3600,
    ):
        self.session_id = session_id
        self.device_id = device_id
        self.telemetry_enc_key = telemetry_enc_key
        self.telemetry_mac_key = telemetry_mac_key
        self.handshake_transcript = handshake_transcript
        self.created_at = datetime.now(timezone.utc)
        self.expires_at = self.created_at + timedelta(seconds=ttl_seconds)

        # Replay Protection State
        self.last_sequence_number = 0
        self.seen_nonces: Set[str] = set()
        self.packet_count = 0

    def is_expired(self, current_time: Optional[datetime] = None) -> bool:
        now = current_time or datetime.now(timezone.utc)
        return now >= self.expires_at


class SecurityIncidentRecord:
    def __init__(
        self,
        incident_type: str,
        device_id: str,
        session_id: Optional[str],
        description: str,
        severity: str = "critical",
    ):
        self.incident_id = f"INC-{uuid.uuid4().hex[:12].upper()}"
        self.incident_type = incident_type
        self.device_id = device_id
        self.session_id = session_id
        self.description = description
        self.severity = severity
        self.timestamp = datetime.now(timezone.utc).isoformat()

    def to_dict(self) -> Dict[str, Any]:
        return {
            "incident_id": self.incident_id,
            "incident_type": self.incident_type,
            "device_id": self.device_id,
            "session_id": self.session_id,
            "description": self.description,
            "severity": self.severity,
            "timestamp": self.timestamp,
        }


class SecurityStateManager:
    """Manages all device identities, cryptographic handshakes, and replay states."""

    FRESHNESS_WINDOW_SECONDS = 60  # Allow up to ±60s clock skew

    def __init__(self):
        self.devices: Dict[str, DeviceRecord] = {}
        self.active_sessions: Dict[str, SecureSession] = {}
        self.device_to_session: Dict[str, str] = {}
        self.incidents: List[SecurityIncidentRecord] = []
        self.audit_log_chain: List[Dict[str, Any]] = []
        self.audit_head_hash = "GENESIS_SECUREMED_AUDIT_ROOT_00000000000000000000000000000000"

    # -------------------------------------------------------------
    # Device Credential & Revocation Management
    # -------------------------------------------------------------

    def seed_default_devices(self):
        """Seed default hospital fleet devices with ML-DSA-65 keys."""
        default_fleet = [
            ("MED-DEV-ICU-701A", "Multi-parameter Vital Monitor"),
            ("MED-DEV-INF-412C", "Continuous Infusion Controller"),
            ("MED-DEV-VENT-901B", "Autonomous Respiratory Assist"),
        ]
        for dev_id, dev_type in default_fleet:
            if dev_id not in self.devices:
                _, pub = RealPQCCryptoEngine.generate_dsa_keypair()
                pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(pub)
                self.register_device(dev_id, dev_type, pub_bytes)

    def register_device(
        self,
        device_id: str,
        device_type: str,
        dsa_public_key_raw: bytes,
    ) -> DeviceRecord:
        """Register device public key identity."""
        if device_id in self.devices and self.devices[device_id].is_revoked:
            raise ValueError(f"Cannot re-register revoked device ID: {device_id}")

        pub_key = RealPQCCryptoEngine.deserialize_dsa_public_key(dsa_public_key_raw)
        record = DeviceRecord(
            device_id=device_id,
            device_type=device_type,
            dsa_public_key=pub_key,
            dsa_pub_bytes=dsa_public_key_raw,
        )
        self.devices[device_id] = record
        self._record_audit_event("DEVICE_REGISTERED", device_id, {"device_type": device_type})
        return record

    def revoke_device(self, device_id: str, reason: str = "Admin revocation") -> bool:
        """Revoke device credential and destroy all active cryptographic sessions."""
        device = self.devices.get(device_id)
        if not device:
            return False

        device.revoke()

        # Invalidate any active session immediately
        if device_id in self.device_to_session:
            sess_id = self.device_to_session.pop(device_id)
            self.active_sessions.pop(sess_id, None)

        self._record_security_incident(
            incident_type="DEVICE_REVOKED",
            device_id=device_id,
            session_id=None,
            description=f"Device credentials revoked. Reason: {reason}",
            severity="warning",
        )
        self._record_audit_event("DEVICE_REVOKED", device_id, {"reason": reason})
        return True

    def get_device(self, device_id: str) -> Optional[DeviceRecord]:
        return self.devices.get(device_id)

    # -------------------------------------------------------------
    # Session Management
    # -------------------------------------------------------------

    def create_session(
        self,
        device_id: str,
        shared_secret: bytes,
        salt: bytes,
        transcript_bytes: bytes,
        ttl_seconds: int = 3600,
    ) -> SecureSession:
        """Derives independent keys and binds session to device."""
        device = self.devices.get(device_id)
        if not device or device.is_revoked:
            raise ValueError(f"Device '{device_id}' is revoked or not registered.")

        # Invalidate previous session for this device
        if device_id in self.device_to_session:
            old_sess = self.device_to_session.pop(device_id)
            self.active_sessions.pop(old_sess, None)

        keys = RealPQCCryptoEngine.derive_session_keys(
            shared_secret=shared_secret,
            salt=salt,
            context_transcript=transcript_bytes,
        )

        session_id = f"SES-{uuid.uuid4().hex[:16]}"
        session = SecureSession(
            session_id=session_id,
            device_id=device_id,
            telemetry_enc_key=keys["telemetry_enc_key"],
            telemetry_mac_key=keys["telemetry_mac_key"],
            handshake_transcript=RealPQCCryptoEngine.compute_sha256(transcript_bytes),
            ttl_seconds=ttl_seconds,
        )

        self.active_sessions[session_id] = session
        self.device_to_session[device_id] = session_id

        self._record_audit_event(
            "PQC_SESSION_ESTABLISHED",
            device_id,
            {"session_id": session_id, "ttl": ttl_seconds},
        )
        return session

    def get_session(self, session_id: str) -> Optional[SecureSession]:
        session = self.active_sessions.get(session_id)
        if session and session.is_expired():
            self.terminate_session(session_id, reason="Expired")
            return None
        return session

    def terminate_session(self, session_id: str, reason: str = "Explicit termination"):
        session = self.active_sessions.pop(session_id, None)
        if session:
            self.device_to_session.pop(session.device_id, None)
            self._record_audit_event("SESSION_TERMINATED", session.device_id, {"reason": reason})

    # -------------------------------------------------------------
    # Replay Protection & Freshness Validation
    # -------------------------------------------------------------

    def validate_incoming_telemetry_envelope(
        self,
        session_id: str,
        device_id: str,
        sequence_number: int,
        timestamp_iso: str,
        nonce_b64: str,
    ) -> Tuple[bool, str, Optional[SecureSession]]:
        """Validates session state, device revocation, freshness window, sequence order, and nonce uniqueness."""
        # 1. Device status verification
        device = self.devices.get(device_id)
        if not device:
            return False, "DEVICE_NOT_REGISTERED", None
        if device.is_revoked:
            self._record_security_incident(
                "REVOKED_DEVICE_TRANSMISSION_ATTEMPT",
                device_id,
                session_id,
                "Revoked device attempted to transmit telemetry",
            )
            return False, "DEVICE_IS_REVOKED", None

        # 2. Session verification
        session = self.active_sessions.get(session_id)
        if not session:
            return False, "SESSION_NOT_FOUND", None
        if session.is_expired():
            self._record_security_incident(
                "EXPIRED_SESSION_ATTEMPT",
                device_id,
                session_id,
                "Telemetry transmitted under expired session",
            )
            self.terminate_session(session_id, "Session expired")
            return False, "SESSION_EXPIRED", None
        if session.device_id != device_id:
            self._record_security_incident(
                "SESSION_HIJACK_ATTEMPT",
                device_id,
                session_id,
                f"Device {device_id} attempted to use session of {session.device_id}",
            )
            return False, "SESSION_DEVICE_MISMATCH", None

        # 3. Temporal Freshness Window Check
        try:
            msg_time = datetime.fromisoformat(timestamp_iso)
            now = datetime.now(timezone.utc)
            delta = abs((now - msg_time).total_seconds())
            if delta > self.FRESHNESS_WINDOW_SECONDS:
                self._record_security_incident(
                    "STALE_TIMESTAMP_OUTSIDE_FRESHNESS_WINDOW",
                    device_id,
                    session_id,
                    f"Message timestamp drifted by {delta:.1f}s (max allowed: {self.FRESHNESS_WINDOW_SECONDS}s)",
                )
                return False, f"STALE_TIMESTAMP: Drift {delta:.1f}s exceeds {self.FRESHNESS_WINDOW_SECONDS}s window", None
        except Exception:
            return False, "MALFORMED_TIMESTAMP_FORMAT", None

        # 4. Strict Monotonic Sequence Check
        if sequence_number <= session.last_sequence_number:
            self._record_security_incident(
                "DUPLICATE_SEQUENCE_NUMBER_REPLAY",
                device_id,
                session_id,
                f"Replay detected: received sequence {sequence_number} <= last seen {session.last_sequence_number}",
            )
            return False, f"REPLAY_ATTACK_DETECTED: Sequence {sequence_number} is duplicate or out-of-order", None

        # 5. Nonce-Reuse Check
        if nonce_b64 in session.seen_nonces:
            self._record_security_incident(
                "NONCE_REUSE_DETECTED",
                device_id,
                session_id,
                "Reused nonce detected under the same active session key",
            )
            return False, "NONCE_REUSE_DETECTED: Cryptographic nonce reuse forbidden", None

        # Record validation state
        session.seen_nonces.add(nonce_b64)
        session.last_sequence_number = sequence_number
        session.packet_count += 1
        return True, "VALID", session

    # -------------------------------------------------------------
    # Tamper-Evident Audit Hash Chaining & External Anchoring
    # -------------------------------------------------------------

    def _record_audit_event(
        self,
        event_type: str,
        device_id: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
        actor: Optional[str] = None,
        result: str = "SUCCESS",
        event_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Appends a new security-relevant event to the SHA-256 cryptographic hash chain."""
        now = datetime.now(timezone.utc).isoformat()
        evt_id = event_id or f"EVT-{uuid.uuid4().hex[:12].upper()}"
        effective_actor = actor or device_id or "SYSTEM_GATEWAY"
        effective_device_id = device_id or actor or "GATEWAY"
        effective_details = details or {}

        # Canonical hash payload: timestamp|event_id|actor|event_type|result|details
        payload = f"{now}|{evt_id}|{effective_actor}|{event_type}|{result}|{str(effective_details)}".encode("utf-8")
        new_hash = RealPQCCryptoEngine.compute_audit_chain_hash(self.audit_head_hash, payload)

        event = {
            "index": len(self.audit_log_chain) + 1,
            "event_id": evt_id,
            "timestamp": now,
            "actor": effective_actor,
            "device_id": effective_device_id,  # backward compatibility
            "event_type": event_type,
            "event": event_type,  # backward compatibility
            "result": result,
            "details": effective_details,
            "previous_hash": self.audit_head_hash,
            "parent_hash": self.audit_head_hash,  # backward compatibility
            "entry_hash": new_hash,
            "block_hash": new_hash,  # backward compatibility
        }
        self.audit_head_hash = new_hash
        self.audit_log_chain.append(event)
        return event

    def _record_security_incident(
        self,
        incident_type: str,
        device_id: str,
        session_id: Optional[str],
        description: str,
        severity: str = "critical",
    ):
        record = SecurityIncidentRecord(
            incident_type=incident_type,
            device_id=device_id,
            session_id=session_id,
            description=description,
            severity=severity,
        )
        self.incidents.append(record)
        self._record_audit_event(
            event_type="SECURITY_ALERT_TRIGGERED",
            device_id=device_id,
            details=record.to_dict(),
            actor=device_id,
            result="DETECTED_AND_LOGGED",
        )

    def verify_audit_chain(self, include_details: bool = False) -> Any:
        """Cryptographically verifies the SHA-256 hash chaining of all audit entries.
        
        Returns:
            If include_details is True: Tuple[bool, str, Optional[Dict[str, Any]]]
            Else: Tuple[bool, str]
        """
        expected_prev = "GENESIS_SECUREMED_AUDIT_ROOT_00000000000000000000000000000000"
        for i, entry in enumerate(self.audit_log_chain):
            prev = entry.get("previous_hash") or entry.get("parent_hash")
            if prev != expected_prev:
                fail_info = {
                    "block_index": i + 1,
                    "event_id": entry.get("event_id", f"EVT-BLOCK-{i+1}"),
                    "expected_previous_hash": expected_prev,
                    "actual_previous_hash": prev,
                    "reason": "Broken previous_hash chain linkage",
                }
                msg = f"Broken chain link at block #{i + 1}: parent hash mismatch"
                return (False, msg, fail_info) if include_details else (False, msg)

            # Compute hash using canonical format
            evt_id = entry.get("event_id")
            actor = entry.get("actor") or entry.get("device_id", "SYSTEM")
            evt_type = entry.get("event_type") or entry.get("event", "UNKNOWN")
            res = entry.get("result", "SUCCESS")
            ts = entry.get("timestamp", "")
            details = entry.get("details", {})

            if evt_id:
                payload = f"{ts}|{evt_id}|{actor}|{evt_type}|{res}|{str(details)}".encode("utf-8")
            else:
                payload = f"{ts}|{evt_type}|{actor}|{str(details)}".encode("utf-8")

            recomputed = RealPQCCryptoEngine.compute_audit_chain_hash(expected_prev, payload)
            actual_entry_hash = entry.get("entry_hash") or entry.get("block_hash")

            if actual_entry_hash != recomputed:
                # Also test legacy payload format for backwards compatibility
                legacy_payload = f"{ts}|{evt_type}|{actor}|{str(details)}".encode("utf-8")
                legacy_hash = RealPQCCryptoEngine.compute_audit_chain_hash(expected_prev, legacy_payload)
                if actual_entry_hash != legacy_hash:
                    fail_info = {
                        "block_index": i + 1,
                        "event_id": entry.get("event_id", f"EVT-BLOCK-{i+1}"),
                        "expected_hash": recomputed,
                        "actual_hash": actual_entry_hash,
                        "reason": "Audit record content modified: SHA-256 digest mismatch",
                    }
                    msg = f"Integrity failure at block #{i + 1}: entry hash mismatch"
                    return (False, msg, fail_info) if include_details else (False, msg)

            expected_prev = actual_entry_hash

        success_msg = "All audit ledger blocks intact and cryptographically verified"
        return (True, success_msg, None) if include_details else (True, success_msg)

    def get_anchoring_digest(self) -> Dict[str, Any]:
        """Produces cryptographic anchoring digest of the latest ledger state for external anchoring."""
        chain_len = len(self.audit_log_chain)
        latest_entry = self.audit_log_chain[-1] if self.audit_log_chain else None
        latest_ts = latest_entry["timestamp"] if latest_entry else datetime.now(timezone.utc).isoformat()
        latest_evt_id = latest_entry.get("event_id", "GENESIS") if latest_entry else "GENESIS"

        anchor_str = f"{self.audit_head_hash}:{chain_len}:{latest_ts}"
        anchoring_digest = hashlib.sha256(anchor_str.encode("utf-8")).hexdigest()

        return {
            "audit_head_hash": self.audit_head_hash,
            "chain_length": chain_len,
            "latest_event_id": latest_evt_id,
            "latest_timestamp": latest_ts,
            "anchoring_digest": anchoring_digest,
            "anchoring_format": "SHA256(head_hash:chain_length:latest_timestamp)",
            "anchored_at": datetime.now(timezone.utc).isoformat(),
            "limitation_disclosure": (
                "SECURITY LIMITATION NOTICE: Local SHA-256 hash chaining guarantees detection of modified, "
                "deleted, or inserted records within an existing chain. However, if an adversary obtains "
                "database-level write access and regenerates the entire chain from genesis, internal verification "
                "cannot detect complete ledger replacement. Periodic anchoring of this digest to an external "
                "immutable authority (e.g. public ledger, RFC 3161 TSA, or transparency log) is required "
                "to defend against whole-database recomputation attacks."
            ),
        }


# Global singleton security state manager for the gateway
security_manager = SecurityStateManager()
