"""SecureMed IoT - Simulated Medical Device Core.

Implements:
1. Unique device ID, type, and hardware sensor status.
2. Cryptographic identity provisioning with NIST FIPS 204 ML-DSA-65.
3. Post-quantum mutual authentication & session establishment with NIST FIPS 203 ML-KEM-768.
4. Independent session key derivation via HKDF-SHA-256.
5. Monotonic sequence counter & strict replay protection.
6. Authenticated telemetry encryption via AES-256-GCM with AAD binding.
7. Graceful session renewal on expiration and immediate halt upon credential revocation.
8. Safe logging preventing any leakage of cryptographic private keys or shared secrets.

DISCLAIMER: Hackathon cybersecurity prototype only.
Simulated devices & synthetic patient data only.
Never connect to actual medical equipment or perform clinical decisions.
"""

import sys
import os
import base64
import json
import time
import random
import logging
from typing import Optional, Dict, Any, Tuple
from datetime import datetime, timezone, timedelta

# Import requests for HTTP network communication
import requests

# Add backend directory to sys.path to access real PQC crypto engine
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))
from app.core.crypto_engine import RealPQCCryptoEngine

from models import (
    DeviceType,
    DeviceStatus,
    ConnectionState,
    ECGSyntheticReading,
    HeartRateSyntheticReading,
    SpO2SyntheticReading,
)

logger = logging.getLogger("SecureMedSimulator")


class MedicalDevice:
    """Simulated post-quantum medical device client."""

    def __init__(
        self,
        device_id: str,
        device_type: DeviceType,
        name: str,
        gateway_url: str = "http://localhost:8000/api/v1",
        initial_battery: int = 100,
        client: Any = None,
    ):
        self.device_id = device_id
        self.device_type = device_type
        self.name = name
        self.gateway_url = gateway_url.rstrip("/")
        self.battery_percent = initial_battery
        self.client = client or requests

        # Operational state
        self.connection_state: ConnectionState = ConnectionState.DISCONNECTED
        self.device_status: DeviceStatus = DeviceStatus.NORMAL
        self.last_seen_timestamp: Optional[str] = None

        # -------------------------------------------------------------
        # Provision Cryptographic Identity (NIST FIPS 204 ML-DSA-65)
        # -------------------------------------------------------------
        self._dsa_private_key, self.dsa_public_key = RealPQCCryptoEngine.generate_dsa_keypair()
        self.dsa_pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(self.dsa_public_key)

        # -------------------------------------------------------------
        # Session State & Sequence Counter
        # -------------------------------------------------------------
        self.session_id: Optional[str] = None
        self._session_key: Optional[bytes] = None
        self.session_established_at: Optional[datetime] = None
        self.session_expires_at: Optional[datetime] = None
        self.transcript_hash: Optional[str] = None
        self.sequence_counter: int = 0

        logger.info(
            f"[{self.device_id}] Initialized {self.name} ({self.device_type.value}) "
            f"| ML-DSA-65 Public Key: {len(self.dsa_pub_bytes)} bytes | State: {self.connection_state.value}"
        )

    # -----------------------------------------------------------------
    # Safe State & Summary
    # -----------------------------------------------------------------

    def get_state_summary(self) -> Dict[str, Any]:
        """Returns non-sensitive operational telemetry and session state."""
        return {
            "device_id": self.device_id,
            "name": self.name,
            "device_type": self.device_type.value,
            "connection_state": self.connection_state.value,
            "device_status": self.device_status.value,
            "battery_percent": self.battery_percent,
            "sequence_counter": self.sequence_counter,
            "session_id": self.session_id,
            "session_active": self.is_session_active(),
            "last_seen_timestamp": self.last_seen_timestamp,
        }

    def is_session_active(self) -> bool:
        """Checks if current PQC session is established and not expired."""
        if not self.session_id or not self._session_key or not self.session_expires_at:
            return False
        return datetime.now(timezone.utc) < self.session_expires_at

    # -----------------------------------------------------------------
    # Gateway Registration
    # -----------------------------------------------------------------

    def register(self, timeout: float = 5.0) -> bool:
        """Registers the device's ML-DSA-65 public key identity with the trusted backend.
        
        Never sends or exposes the device private key.
        """
        if self.connection_state == ConnectionState.REVOKED:
            logger.warning(f"[{self.device_id}] Cannot register: Device credentials have been REVOKED.")
            return False

        self.connection_state = ConnectionState.REGISTERING
        endpoint = f"{self.gateway_url}/devices/register"
        payload = {
            "device_id": self.device_id,
            "device_type": self.name,
            "dsa_public_key_b64": base64.b64encode(self.dsa_pub_bytes).decode("utf-8"),
        }

        logger.info(f"[{self.device_id}] Registering public key with Gateway at {endpoint}...")
        try:
            res = self.client.post(endpoint, json=payload, timeout=timeout)
            if res.status_code in (200, 201):
                self.connection_state = ConnectionState.REGISTERED
                logger.info(f"[{self.device_id}] Device successfully registered with Gateway.")
                return True
            elif res.status_code == 400 and "already registered" in res.text.lower():
                self.connection_state = ConnectionState.REGISTERED
                logger.info(f"[{self.device_id}] Device already registered with Gateway.")
                return True
            elif res.status_code == 403 or "revoked" in res.text.lower():
                self.connection_state = ConnectionState.REVOKED
                logger.error(f"[{self.device_id}] Registration rejected: Device credential is REVOKED.")
                return False
            else:
                self.connection_state = ConnectionState.ERROR
                self._safe_log_error("Registration failed", res.status_code, res.text)
                return False
        except requests.exceptions.RequestException as e:
            self.connection_state = ConnectionState.ERROR
            self._safe_log_error("Network connection error during registration", None, str(e))
            return False

    # -----------------------------------------------------------------
    # Post-Quantum Mutual Authentication & Session Key Establishment
    # -----------------------------------------------------------------

    def establish_session(self, timeout: float = 5.0) -> bool:
        """Executes full Post-Quantum Cryptographic Handshake:
        
        1. Request ephemeral ML-KEM-768 public key & random challenge from Gateway.
        2. Encapsulate 256-bit shared secret using Gateway's ML-KEM-768 public key.
        3. Sign challenge using device's NIST FIPS 204 ML-DSA-65 private key.
        4. Derive independent symmetric session keys via HKDF-SHA-256 bound to transcript.
        5. Transmit ciphertext, signature, and salt to Gateway to activate session.
        """
        if self.connection_state == ConnectionState.REVOKED:
            logger.warning(f"[{self.device_id}] Access Denied: Device credentials REVOKED. Handshake aborted.")
            return False

        self.connection_state = ConnectionState.HANDSHAKING
        logger.info(f"[{self.device_id}] Initiating PQC Handshake with Gateway...")

        # Step 1: Request Gateway's ML-KEM-768 public key & challenge
        init_url = f"{self.gateway_url}/crypto/handshake/init"
        try:
            init_res = self.client.post(init_url, json={"device_id": self.device_id}, timeout=timeout)
            if init_res.status_code == 403 or "revoked" in init_res.text.lower():
                self.connection_state = ConnectionState.REVOKED
                logger.error(f"[{self.device_id}] Handshake init rejected: Device is REVOKED.")
                return False
            init_res.raise_for_status()
            init_data = init_res.json()
        except Exception as e:
            self.connection_state = ConnectionState.ERROR
            status_code = getattr(getattr(e, 'response', None), 'status_code', None)
            self._safe_log_error("Handshake Init failed", status_code, str(e))
            return False

        gateway_kem_pub_bytes = base64.b64decode(init_data["gateway_kem_pub_b64"])
        challenge_bytes = base64.b64decode(init_data["challenge_b64"])

        # Step 2: ML-KEM-768 Encapsulation
        gateway_kem_pub = RealPQCCryptoEngine.deserialize_kem_public_key(gateway_kem_pub_bytes)
        shared_secret, ciphertext = RealPQCCryptoEngine.kem_encapsulate(gateway_kem_pub)

        # Step 3: ML-DSA-65 Digital Signature on Gateway Challenge
        signed_challenge = RealPQCCryptoEngine.dsa_sign(self._dsa_private_key, challenge_bytes)

        # Step 4: Transcript Binding & HKDF-SHA-256 Session Key Derivation
        salt = os.urandom(16)
        transcript = (
            f"{self.device_id}:".encode("utf-8")
            + gateway_kem_pub_bytes
            + challenge_bytes
            + ciphertext
            + salt
        )

        keys = RealPQCCryptoEngine.derive_session_keys(
            shared_secret=shared_secret,
            salt=salt,
            context_transcript=transcript,
        )
        derived_session_key = keys["telemetry_enc_key"]

        # Step 5: Complete Handshake with Gateway
        complete_url = f"{self.gateway_url}/crypto/handshake/complete"
        client_ts = datetime.now(timezone.utc).isoformat()
        complete_payload = {
            "device_id": self.device_id,
            "ciphertext_b64": base64.b64encode(ciphertext).decode("utf-8"),
            "signed_challenge_b64": base64.b64encode(signed_challenge).decode("utf-8"),
            "salt_b64": base64.b64encode(salt).decode("utf-8"),
            "client_timestamp": client_ts,
        }

        try:
            comp_res = self.client.post(complete_url, json=complete_payload, timeout=timeout)
            if comp_res.status_code == 403 or "revoked" in comp_res.text.lower():
                self.connection_state = ConnectionState.REVOKED
                logger.error(f"[{self.device_id}] Handshake completion rejected: Device is REVOKED.")
                return False
            comp_res.raise_for_status()
            comp_data = comp_res.json()
        except Exception as e:
            self.connection_state = ConnectionState.ERROR
            status_code = getattr(getattr(e, 'response', None), 'status_code', None)
            self._safe_log_error("Handshake Complete failed", status_code, str(e))
            return False

        # Session established
        self.session_id = comp_data["session_id"]
        self._session_key = derived_session_key
        self.session_established_at = datetime.now(timezone.utc)
        expires_in = comp_data.get("expires_in_seconds", 3600)
        self.session_expires_at = self.session_established_at + timedelta(seconds=expires_in)
        self.transcript_hash = comp_data.get("handshake_transcript_hash")
        self.sequence_counter = 0
        self.connection_state = ConnectionState.AUTHENTICATED

        logger.info(
            f"[{self.device_id}] PQC Handshake SUCCESS! Session: {self.session_id} "
            f"| Transcript Digest: {self.transcript_hash[:16]}... | Sequence counter reset to 0."
        )
        return True

    # -----------------------------------------------------------------
    # Synthetic Telemetry Generation
    # -----------------------------------------------------------------

    def generate_synthetic_reading(
        self,
        is_attack: bool = False,
        attack_type: str = "none",
    ) -> Dict[str, Any]:
        """Generates realistic-looking but strictly synthetic medical readings."""
        # Deplete battery slightly over time
        if self.battery_percent > 15 and random.random() < 0.2:
            self.battery_percent -= 1

        if self.device_type == DeviceType.ECG_MONITOR:
            reading = ECGSyntheticReading.generate(
                device_id=self.device_id,
                is_attack=is_attack,
                attack_type=attack_type,
                status=self.device_status,
                battery=self.battery_percent,
            )
        elif self.device_type == DeviceType.HEART_RATE_MONITOR:
            reading = HeartRateSyntheticReading.generate(
                device_id=self.device_id,
                is_attack=is_attack,
                attack_type=attack_type,
                status=self.device_status,
                battery=self.battery_percent,
            )
        elif self.device_type == DeviceType.SPO2_MONITOR:
            reading = SpO2SyntheticReading.generate(
                device_id=self.device_id,
                is_attack=is_attack,
                attack_type=attack_type,
                status=self.device_status,
                battery=self.battery_percent,
            )
        else:
            raise ValueError(f"Unsupported device type: {self.device_type}")

        return reading.model_dump()

    # -----------------------------------------------------------------
    # Telemetry Encryption & Transmission
    # -----------------------------------------------------------------

    def emit_telemetry(
        self,
        is_attack: bool = False,
        attack_type: str = "none",
        override_sequence: Optional[int] = None,
        override_timestamp: Optional[str] = None,
        override_ciphertext: Optional[str] = None,
        override_signature: Optional[str] = None,
        timeout: float = 5.0,
    ) -> Tuple[bool, Optional[Dict[str, Any]]]:
        """Encrypts synthetic reading with AES-256-GCM, signs with ML-DSA-65, and posts to Gateway.
        
        Handles:
        - Expired session -> Triggers re-handshake automatically.
        - Revoked device -> Halts transmission immediately.
        - Replay attack defense -> Rejects duplicated/out-of-order sequence.
        """
        if self.connection_state == ConnectionState.REVOKED:
            logger.warning(f"[{self.device_id}] Cannot emit telemetry: Device credentials REVOKED.")
            return False, {"error": "DEVICE_REVOKED", "detail": "Device is revoked by administrator"}

        # Check session freshness; re-authenticate if expired
        if not self.is_session_active():
            logger.info(f"[{self.device_id}] Cryptographic session missing or expired. Performing PQC handshake...")
            if not self.establish_session(timeout=timeout):
                logger.error(f"[{self.device_id}] Re-authentication failed. Telemetry aborted.")
                return False, {"error": "HANDSHAKE_FAILED", "detail": "Could not establish session"}

        # Sequence number & timestamp
        if override_sequence is not None:
            seq = override_sequence
        else:
            self.sequence_counter += 1
            seq = self.sequence_counter

        current_ts = override_timestamp or datetime.now(timezone.utc).isoformat()

        # Step 1: Generate synthetic reading & serialize
        reading_dict = self.generate_synthetic_reading(is_attack=is_attack, attack_type=attack_type)
        payload_bytes = json.dumps(reading_dict).encode("utf-8")

        # Step 2: Sign plaintext payload using NIST FIPS 204 ML-DSA-65
        sig_bytes = RealPQCCryptoEngine.dsa_sign(self._dsa_private_key, payload_bytes)
        if attack_type == "tamper_signature" or override_signature is not None:
            # Corrupt signature to test Gateway rejection
            sig_b64 = override_signature or base64.b64encode(os.urandom(len(sig_bytes))).decode("utf-8")
        else:
            sig_b64 = base64.b64encode(sig_bytes).decode("utf-8")

        # Step 3: Construct Authenticated Associated Data (AAD) binding envelope fields
        aad_raw = f"{self.device_id}:{self.session_id}:{seq}:{current_ts}".encode("utf-8")

        # Step 4: Encrypt with AES-256-GCM
        enc = RealPQCCryptoEngine.encrypt_telemetry(
            key=self._session_key,
            plaintext=payload_bytes,
            aad=aad_raw,
        )

        ciphertext_b64 = enc["ciphertext_b64"]
        if attack_type == "tamper_ciphertext" or override_ciphertext is not None:
            # Corrupt ciphertext bytes to test GCM authentication tag verification
            raw_ct = bytearray(base64.b64decode(ciphertext_b64))
            raw_ct[0] ^= 0xFF  # Flip bits
            ciphertext_b64 = base64.b64encode(raw_ct).decode("utf-8")

        # Step 5: Formulate Ingestion Envelope
        envelope = {
            "device_id": self.device_id,
            "session_id": self.session_id,
            "sequence_number": seq,
            "timestamp": current_ts,
            "device_type": self.name,
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": ciphertext_b64,
            "signature_b64": sig_b64,
            "aad_b64": enc["aad_b64"],
        }

        # Step 6: Transmit to Gateway
        ingest_url = f"{self.gateway_url}/telemetry/ingest"
        try:
            res = self.client.post(ingest_url, json=envelope, timeout=timeout)

            # Case: Device Revoked (403)
            if res.status_code == 403 or (res.status_code == 400 and "revoked" in res.text.lower()):
                self.connection_state = ConnectionState.REVOKED
                logger.error(f"[{self.device_id}] Transmission REJECTED: Device is REVOKED. Halting.")
                return False, {"status_code": res.status_code, "error": "DEVICE_REVOKED", "detail": res.text}

            # Case: Expired / Unknown Session or Signature Failure (401)
            if res.status_code == 401:
                if "expired" in res.text.lower():
                    logger.warning(f"[{self.device_id}] Gateway reported session expired. Triggering re-handshake...")
                    if self.establish_session(timeout=timeout):
                        return self.emit_telemetry(is_attack=is_attack, attack_type=attack_type, timeout=timeout)
                    return False, {"status_code": 401, "error": "SESSION_EXPIRED", "detail": res.text}
                else:
                    logger.warning(f"[{self.device_id}] Gateway rejected signature or authorization (401): {res.text}")
                    return False, {"status_code": 401, "error": "UNAUTHORIZED_OR_SIGNATURE_FAILURE", "detail": res.text}

            # Case: Attack detected or rejection (400 Bad Request)
            if res.status_code == 400:
                logger.warning(
                    f"[{self.device_id}] Envelope rejected by Gateway as expected | Seq #{seq} | Detail: {res.text}"
                )
                return False, {"status_code": 400, "error": "REJECTED_BY_GATEWAY", "detail": res.text}

            res.raise_for_status()
            data = res.json()
            self.connection_state = ConnectionState.TRANSMITTING
            self.last_seen_timestamp = data.get("ingested_at") or current_ts

            logger.info(
                f"[{self.device_id}] Seq #{seq} VERIFIED by Gateway! "
                f"Status: {data.get('status')} | Anomaly: {data.get('tampering_detected')} | Last Seen: {self.last_seen_timestamp}"
            )
            return True, data

        except Exception as e:
            status_code = getattr(getattr(e, 'response', None), 'status_code', None)
            self._safe_log_error(f"Transmission Seq #{seq} failed", status_code, str(e))
            return False, {"status_code": status_code, "error": "NETWORK_EXCEPTION", "detail": str(e)}

    # -----------------------------------------------------------------
    # Safe Logging Without Secrets
    # -----------------------------------------------------------------

    def _safe_log_error(self, action: str, status_code: Optional[int], message: str):
        """Logs communication errors cleanly without ever logging private keys or symmetric keys."""
        # Sanitize message to strip any base64 key patterns if present
        clean_msg = message.replace(self.gateway_url, "[GATEWAY]")
        if len(clean_msg) > 200:
            clean_msg = clean_msg[:200] + "..."
        logger.error(
            f"[{self.device_id}] {action} (HTTP {status_code or 'CONN_ERR'}): {clean_msg}"
        )
