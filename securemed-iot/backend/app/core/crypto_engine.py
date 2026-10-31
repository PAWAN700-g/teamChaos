"""SecureMed IoT - Post-Quantum Cryptographic Engine.

Implements:
1. ML-KEM-768 (NIST FIPS 203) - Post-Quantum Key Encapsulation Mechanism
2. ML-DSA-65 (NIST FIPS 204) - Post-Quantum Digital Signature Algorithm
3. AES-256-GCM (NIST SP 800-38D) - Authenticated Encryption with Associated Data (AEAD)
4. HKDF-SHA-256 (RFC 5869) - Ephemeral Key Derivation Function
5. SHA-256 (FIPS 180-4) - Firmware Fingerprints and Immutable Audit Hash Chaining

Library Implementation:
- Python 'cryptography' >= 50.0.2 (OpenSSL 3.5+ / Rust PyCA backend).
- Algorithm Identifiers:
  * KEM: 'ML-KEM-768' (FIPS 203, Parameter Set 768, Category 3 Security)
  * DSA: 'ML-DSA-65' (FIPS 204, Parameter Set 65, Category 3 Security)
  * AEAD: 'AES-256-GCM'
  * KDF: 'HKDF-SHA-256'
  * HASH: 'SHA-256'
"""

import os
import base64
import hashlib
from typing import Tuple, Dict, Any, Optional, Union

import cryptography
from cryptography.hazmat.primitives.asymmetric import mlkem, mldsa
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes


class CryptographicEngineMetadata:
    """Records library versions, algorithm identifiers, and security parameters."""
    ENGINE_NAME = "SecureMed-PQC-Engine"
    CRYPTOGRAPHY_VERSION = cryptography.__version__
    PQC_BACKEND = "PyCA-Rust/OpenSSL-3.5+ Standard Engine"
    
    # Standard Algorithm Identifiers
    ALGORITHM_KEM = "ML-KEM-768"
    ALGORITHM_DSA = "ML-DSA-65"
    ALGORITHM_AEAD = "AES-256-GCM"
    ALGORITHM_KDF = "HKDF-SHA-256"
    ALGORITHM_HASH = "SHA-256"

    # Key and Signature Sizes (in bytes)
    ML_KEM_768_PUBLIC_KEY_SIZE = 1184
    ML_KEM_768_CIPHERTEXT_SIZE = 1088
    ML_KEM_768_SHARED_SECRET_SIZE = 32
    ML_DSA_65_PUBLIC_KEY_SIZE = 1952
    ML_DSA_65_SIGNATURE_SIZE = 3309
    AES_256_KEY_SIZE = 32
    GCM_NONCE_SIZE = 12
    GCM_TAG_SIZE = 16

    @classmethod
    def get_info(cls) -> Dict[str, Any]:
        return {
            "engine": cls.ENGINE_NAME,
            "library_version": cls.CRYPTOGRAPHY_VERSION,
            "pqc_backend": cls.PQC_BACKEND,
            "is_real_pqc": True,
            "mock_mode": False,
            "algorithms": {
                "key_establishment": {
                    "algorithm": cls.ALGORITHM_KEM,
                    "standard": "NIST FIPS 203",
                    "public_key_bytes": cls.ML_KEM_768_PUBLIC_KEY_SIZE,
                    "ciphertext_bytes": cls.ML_KEM_768_CIPHERTEXT_SIZE,
                    "shared_secret_bytes": cls.ML_KEM_768_SHARED_SECRET_SIZE,
                },
                "digital_signature": {
                    "algorithm": cls.ALGORITHM_DSA,
                    "standard": "NIST FIPS 204",
                    "public_key_bytes": cls.ML_DSA_65_PUBLIC_KEY_SIZE,
                    "signature_bytes": cls.ML_DSA_65_SIGNATURE_SIZE,
                },
                "authenticated_encryption": {
                    "algorithm": cls.ALGORITHM_AEAD,
                    "standard": "NIST SP 800-38D",
                    "key_bytes": cls.AES_256_KEY_SIZE,
                    "nonce_bytes": cls.GCM_NONCE_SIZE,
                    "tag_bytes": cls.GCM_TAG_SIZE,
                },
                "key_derivation": {
                    "algorithm": cls.ALGORITHM_KDF,
                    "standard": "RFC 5869",
                },
                "integrity_hash": {
                    "algorithm": cls.ALGORITHM_HASH,
                    "standard": "FIPS 180-4",
                },
            },
        }


class RealPQCCryptoEngine:
    """Core Cryptographic Security Engine implementing NIST FIPS 203 & 204."""

    # -------------------------------------------------------------
    # 1. ML-KEM-768 (NIST FIPS 203) Key Encapsulation
    # -------------------------------------------------------------

    @staticmethod
    def generate_kem_keypair() -> Tuple[mlkem.MLKEM768PrivateKey, mlkem.MLKEM768PublicKey]:
        """Generate a NIST FIPS 203 ML-KEM-768 key pair."""
        private_key = mlkem.MLKEM768PrivateKey.generate()
        return private_key, private_key.public_key()

    @staticmethod
    def serialize_kem_public_key(public_key: mlkem.MLKEM768PublicKey) -> bytes:
        """Serialize ML-KEM-768 public key to raw 1,184 bytes."""
        return public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )

    @staticmethod
    def deserialize_kem_public_key(raw_bytes: bytes) -> mlkem.MLKEM768PublicKey:
        """Deserialize raw 1,184 bytes into ML-KEM-768 public key."""
        return mlkem.MLKEM768PublicKey.from_public_bytes(raw_bytes)

    @staticmethod
    def kem_encapsulate(public_key: mlkem.MLKEM768PublicKey) -> Tuple[bytes, bytes]:
        """Encapsulate shared secret using peer's ML-KEM-768 public key.

        Returns:
            Tuple[bytes, bytes]: (shared_secret_32_bytes, ciphertext_1088_bytes)
        """
        shared_secret, ciphertext = public_key.encapsulate()
        return shared_secret, ciphertext

    @staticmethod
    def kem_decapsulate(private_key: mlkem.MLKEM768PrivateKey, ciphertext: bytes) -> bytes:
        """Decapsulate ciphertext to recover the 32-byte shared secret."""
        return private_key.decapsulate(ciphertext)

    # -------------------------------------------------------------
    # 2. ML-DSA-65 (NIST FIPS 204) Digital Signatures
    # -------------------------------------------------------------

    @staticmethod
    def generate_dsa_keypair() -> Tuple[mldsa.MLDSA65PrivateKey, mldsa.MLDSA65PublicKey]:
        """Generate a NIST FIPS 204 ML-DSA-65 key pair."""
        private_key = mldsa.MLDSA65PrivateKey.generate()
        return private_key, private_key.public_key()

    @staticmethod
    def serialize_dsa_public_key(public_key: mldsa.MLDSA65PublicKey) -> bytes:
        """Serialize ML-DSA-65 public key to raw 1,952 bytes."""
        return public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )

    @staticmethod
    def deserialize_dsa_public_key(raw_bytes: bytes) -> mldsa.MLDSA65PublicKey:
        """Deserialize raw 1,952 bytes into ML-DSA-65 public key."""
        return mldsa.MLDSA65PublicKey.from_public_bytes(raw_bytes)

    @staticmethod
    def dsa_sign(private_key: mldsa.MLDSA65PrivateKey, message: bytes, context: Optional[bytes] = None) -> bytes:
        """Sign message using ML-DSA-65 private key (generates 3,309-byte signature)."""
        return private_key.sign(message, context=context)

    @staticmethod
    def dsa_verify(public_key: mldsa.MLDSA65PublicKey, signature: bytes, message: bytes, context: Optional[bytes] = None) -> bool:
        """Verify an ML-DSA-65 digital signature."""
        try:
            public_key.verify(signature, message, context=context)
            return True
        except Exception:
            return False

    # -------------------------------------------------------------
    # 3. HKDF-SHA-256 Key Derivation
    # -------------------------------------------------------------

    @staticmethod
    def derive_session_key(
        shared_secret: bytes,
        salt: Optional[bytes] = None,
        info: bytes = b"securemed-pqc-session",
    ) -> bytes:
        """Derive a single 256-bit symmetric session key using HKDF-SHA-256."""
        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            info=info,
        )
        return hkdf.derive(shared_secret)

    @staticmethod
    def derive_session_keys(shared_secret: bytes, salt: bytes, context_transcript: bytes) -> Dict[str, bytes]:
        """Derive distinct, independent 256-bit session keys using HKDF-SHA-256.

        Derives:
        1. 'telemetry_enc_key': Dedicated for AES-256-GCM telemetry stream encryption.
        2. 'telemetry_mac_key': Dedicated for MAC / message integrity verification.
        """
        hkdf_enc = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            info=b"securemed-v1-telemetry-enc-aes256" + context_transcript,
        )
        enc_key = hkdf_enc.derive(shared_secret)

        hkdf_mac = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            info=b"securemed-v1-telemetry-mac-sha256" + context_transcript,
        )
        mac_key = hkdf_mac.derive(shared_secret)

        return {
            "telemetry_enc_key": enc_key,
            "telemetry_mac_key": mac_key,
        }

    # -------------------------------------------------------------
    # 4. AES-256-GCM Authenticated Encryption
    # -------------------------------------------------------------

    @staticmethod
    def encrypt_telemetry(
        key: bytes,
        plaintext: bytes,
        aad: bytes,
        nonce: Optional[bytes] = None,
    ) -> Dict[str, str]:
        """Encrypt patient telemetry using AES-256-GCM with Authenticated Associated Data (AAD).

        Args:
            key: 256-bit symmetric session key.
            plaintext: Raw payload bytes (synthetic vitals).
            aad: Authenticated Associated Data (device_id, session_id, sequence_number, timestamp).
            nonce: 96-bit (12-byte) initialization vector. If None, generated via os.urandom(12).

        Returns:
            Dict containing base64-encoded nonce, ciphertext (including 16-byte auth tag), and aad.
        """
        if len(key) != 32:
            raise ValueError(f"AES-256 key must be exactly 32 bytes (got {len(key)})")

        if nonce is None:
            nonce = os.urandom(12)
        elif len(nonce) != 12:
            raise ValueError(f"GCM nonce must be exactly 12 bytes (got {len(nonce)})")

        aesgcm = AESGCM(key)
        ciphertext_with_tag = aesgcm.encrypt(nonce, plaintext, aad)

        nonce_b64 = base64.b64encode(nonce).decode("utf-8")
        ct_b64 = base64.b64encode(ciphertext_with_tag).decode("utf-8")
        aad_b64 = base64.b64encode(aad).decode("utf-8")

        return {
            "nonce_b64": nonce_b64,
            "ciphertext_b64": ct_b64,
            "aad_b64": aad_b64,
            "nonce": nonce_b64,
            "ciphertext": ct_b64,
            "aad": aad_b64,
        }

    @staticmethod
    def decrypt_telemetry(
        key: Optional[bytes] = None,
        nonce_b64: Union[str, bytes] = "",
        ciphertext_b64: Union[str, bytes] = "",
        aad_b64: Union[str, bytes] = "",
        session_key: Optional[bytes] = None,
    ) -> bytes:
        """Decrypt and authenticate patient telemetry using AES-256-GCM.

        Raises:
            cryptography.exceptions.InvalidTag: If the ciphertext or AAD has been tampered with.
        """
        enc_key = key if key is not None else session_key
        if enc_key is None or len(enc_key) != 32:
            raise ValueError(f"AES-256 key must be exactly 32 bytes (got {len(enc_key) if enc_key else 0})")

        def _decode(val: Union[str, bytes]) -> bytes:
            if isinstance(val, bytes):
                try:
                    return base64.b64decode(val)
                except Exception:
                    return val
            return base64.b64decode(val)

        nonce = _decode(nonce_b64)
        ciphertext = _decode(ciphertext_b64)
        aad = _decode(aad_b64)

        if len(nonce) != 12:
            raise ValueError(f"GCM nonce must be exactly 12 bytes (got {len(nonce)})")

        aesgcm = AESGCM(enc_key)
        return aesgcm.decrypt(nonce, ciphertext, aad)

    # -------------------------------------------------------------
    # 5. SHA-256 Firmware Fingerprints & Audit Hash Chaining
    # -------------------------------------------------------------

    @staticmethod
    def compute_sha256(data: bytes) -> str:
        """Compute SHA-256 cryptographic digest in hexadecimal."""
        return hashlib.sha256(data).hexdigest()

    @staticmethod
    def verify_firmware_package(
        firmware_bytes: bytes,
        expected_sha256: str,
        signature: bytes,
        signing_public_key: mldsa.MLDSA65PublicKey,
    ) -> bool:
        """Verify firmware binary using SHA-256 hash check and ML-DSA-65 signature."""
        computed_hash = hashlib.sha256(firmware_bytes).hexdigest()
        if computed_hash.lower() != expected_sha256.lower():
            return False
        return RealPQCCryptoEngine.dsa_verify(signing_public_key, signature, firmware_bytes)

    @staticmethod
    def compute_audit_chain_hash(previous_hash: str, log_payload: bytes) -> str:
        """Computes next link in the tamper-evident audit log hash chain."""
        hasher = hashlib.sha256()
        hasher.update(previous_hash.encode("utf-8"))
        hasher.update(log_payload)
        return hasher.hexdigest()


# Export alias
PQCCryptoEngine = RealPQCCryptoEngine
