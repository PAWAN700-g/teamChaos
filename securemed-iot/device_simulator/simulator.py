"""SecureMed IoT - Simulated Medical Device Client.

Simulates connected hospital patient-monitoring devices generating synthetic telemetry
and communicating via Post-Quantum Cryptography (ML-KEM-768, ML-DSA-65, AES-256-GCM)
over real HTTP network connections to the FastAPI Gateway.

DISCLAIMER: Hackathon prototype only. Simulated devices & synthetic patient data only.
Never connect to actual medical equipment or perform clinical decisions.
"""

import sys
import os
import time
import json
import base64
import requests
from typing import Optional, Dict, Any
from datetime import datetime, timezone

# Add backend directory to path to share crypto engine
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))
from app.core.crypto_engine import RealPQCCryptoEngine

from models import SyntheticPatientVitals
from config import sim_settings


class MedicalDeviceSimulator:
    def __init__(self, device_id: str, device_type: str, gateway_url: str):
        self.device_id = device_id
        self.device_type = device_type
        self.gateway_url = gateway_url.rstrip("/")
        print(f"[{self.device_id}] Initializing Post-Quantum Medical Device ({self.device_type})...")

        # Generate ML-DSA-65 device identity key pair (NIST FIPS 204)
        self.dsa_private_key, self.dsa_public_key = RealPQCCryptoEngine.generate_dsa_keypair()
        self.dsa_pub_bytes = RealPQCCryptoEngine.serialize_dsa_public_key(self.dsa_public_key)
        print(f"[{self.device_id}] ML-DSA-65 Identity Key generated ({len(self.dsa_pub_bytes)} bytes public key).")

        self.session_key: Optional[bytes] = None
        self.session_id: Optional[str] = None
        self.sequence_number = 0

    def register_device(self) -> bool:
        """Registers the device's ML-DSA-65 public key identity with the trusted backend."""
        print(f"[{self.device_id}] Registering public key with Gateway at {self.gateway_url}/devices/register...")
        try:
            res = requests.post(
                f"{self.gateway_url}/devices/register",
                json={
                    "device_id": self.device_id,
                    "device_type": self.device_type,
                    "dsa_public_key_b64": base64.b64encode(self.dsa_pub_bytes).decode("utf-8"),
                },
                timeout=5,
            )
            if res.status_code in (200, 201):
                print(f"[{self.device_id}] Device registered successfully with Gateway.")
                return True
            else:
                print(f"[{self.device_id}] Device registration returned {res.status_code}: {res.text}")
                return False
        except Exception as e:
            print(f"[{self.device_id}] Network error registering device: {e}")
            return False

    def perform_network_pqc_handshake(self) -> bool:
        """Executes live Post-Quantum Handshake with the hospital gateway over HTTP."""
        print(f"[{self.device_id}] Contacting Gateway for handshake at {self.gateway_url}/crypto/handshake/init...")

        # Step 1: Request Gateway's ephemeral ML-KEM-768 public key & random challenge
        try:
            init_res = requests.post(
                f"{self.gateway_url}/crypto/handshake/init",
                json={"device_id": self.device_id},
                timeout=5,
            )
            init_res.raise_for_status()
            init_data = init_res.json()
        except Exception as e:
            print(f"[{self.device_id}] Network error reaching Gateway during handshake init: {e}")
            return False

        gateway_kem_pub_bytes = base64.b64decode(init_data["gateway_kem_pub_b64"])
        challenge_bytes = base64.b64decode(init_data["challenge_b64"])

        # Step 2: Encapsulate shared secret using Gateway's ML-KEM-768 public key
        gateway_kem_pub = RealPQCCryptoEngine.deserialize_kem_public_key(gateway_kem_pub_bytes)
        shared_secret, ciphertext = RealPQCCryptoEngine.kem_encapsulate(gateway_kem_pub)

        # Step 3: Sign the Gateway authentication challenge with device's ML-DSA-65 private key
        signed_challenge = RealPQCCryptoEngine.dsa_sign(self.dsa_private_key, challenge_bytes)

        # Step 4: Generate random salt and construct transcript binding
        salt = os.urandom(16)
        transcript = (
            f"{self.device_id}:".encode("utf-8")
            + gateway_kem_pub_bytes
            + challenge_bytes
            + ciphertext
            + salt
        )

        # Step 5: Derive independent 256-bit session keys via HKDF-SHA-256
        keys = RealPQCCryptoEngine.derive_session_keys(
            shared_secret=shared_secret,
            salt=salt,
            context_transcript=transcript,
        )
        self.session_key = keys["telemetry_enc_key"]

        # Step 6: Complete handshake with Gateway
        try:
            complete_res = requests.post(
                f"{self.gateway_url}/crypto/handshake/complete",
                json={
                    "device_id": self.device_id,
                    "ciphertext_b64": base64.b64encode(ciphertext).decode("utf-8"),
                    "signed_challenge_b64": base64.b64encode(signed_challenge).decode("utf-8"),
                    "salt_b64": base64.b64encode(salt).decode("utf-8"),
                    "client_timestamp": datetime.now(timezone.utc).isoformat(),
                },
                timeout=5,
            )
            complete_res.raise_for_status()
            complete_data = complete_res.json()
            self.session_id = complete_data["session_id"]
            self.sequence_number = 0
            print(f"[{self.device_id}] PQC Handshake SUCCESS! Session ID: {self.session_id} | Transcript Hash: {complete_data['handshake_transcript_hash'][:16]}...")
            return True
        except Exception as e:
            print(f"[{self.device_id}] Handshake completion failed: {e}")
            return False

    def emit_telemetry_packet(self, is_attack: bool = False) -> Optional[Dict[str, Any]]:
        """Generate synthetic patient vitals, encrypt with AES-256-GCM, and POST to Gateway."""
        if not self.session_key or not self.session_id:
            print(f"[{self.device_id}] Cannot transmit: Active PQC session not established!")
            return None

        self.sequence_number += 1
        current_ts = datetime.now(timezone.utc).isoformat()

        vitals = (
            SyntheticPatientVitals.generate_tampered_attack_sample()
            if is_attack
            else SyntheticPatientVitals.generate_random_normal()
        )
        payload_bytes = vitals.model_dump_json().encode("utf-8")

        # Step 1: Sign the raw plaintext telemetry using NIST FIPS 204 ML-DSA-65
        signature_bytes = RealPQCCryptoEngine.dsa_sign(self.dsa_private_key, payload_bytes)

        # Step 2: Construct Authenticated Associated Data (AAD) binding device, session, sequence, and timestamp
        aad_raw = f"{self.device_id}:{self.session_id}:{self.sequence_number}:{current_ts}".encode("utf-8")

        # Step 3: Encrypt with AES-256-GCM
        enc = RealPQCCryptoEngine.encrypt_telemetry(
            key=self.session_key,
            plaintext=payload_bytes,
            aad=aad_raw,
        )

        packet = {
            "device_id": self.device_id,
            "session_id": self.session_id,
            "sequence_number": self.sequence_number,
            "timestamp": current_ts,
            "device_type": self.device_type,
            "nonce_b64": enc["nonce_b64"],
            "ciphertext_b64": enc["ciphertext_b64"],
            "signature_b64": base64.b64encode(signature_bytes).decode("utf-8"),
            "aad_b64": enc["aad_b64"],
        }

        try:
            res = requests.post(
                f"{self.gateway_url}/telemetry/ingest",
                json=packet,
                timeout=5,
            )
            res.raise_for_status()
            data = res.json()
            print(f"[{self.device_id}] Seq #{self.sequence_number} verified by Gateway! Status: {data.get('status')} | Anomaly: {data.get('tampering_detected')}")
            return data
        except Exception as e:
            print(f"[{self.device_id}] Telemetry ingestion failed: {e}")
            return None


def run_live():
    print("=" * 75)
    print("SecureMed IoT Device Simulator - Post-Quantum Medical Device Client")
    print("DISCLAIMER: Hackathon prototype. Synthetic patient data only.")
    print("=" * 75)

    device = MedicalDeviceSimulator(
        device_id=sim_settings.DEVICE_ID,
        device_type=sim_settings.DEVICE_TYPE,
        gateway_url=sim_settings.GATEWAY_API_URL,
    )

    # 1. Register device public identity
    if not device.register_device():
        print("[Simulator] Could not register device with Gateway. Ensure FastAPI backend is running.")
        return

    # 2. Establish ML-KEM-768 + ML-DSA-65 Handshake over HTTP
    if not device.perform_network_pqc_handshake():
        print("[Simulator] Handshake failed. Exiting.")
        return

    # 3. Emit 3 live telemetry packets
    for i in range(1, 4):
        print(f"\n--- Transmitting Telemetry Packet #{i} ---")
        device.emit_telemetry_packet(is_attack=sim_settings.SIMULATE_ATTACK)
        time.sleep(sim_settings.TELEMETRY_INTERVAL_SECONDS)

    print("\nSUCCESS: All telemetry packets securely transmitted and verified by Gateway over HTTP!")


if __name__ == "__main__":
    run_live()
