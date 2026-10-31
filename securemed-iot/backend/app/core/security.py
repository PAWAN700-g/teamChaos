"""SecureMed IoT - Cryptographic Module Facade."""

from app.core.crypto_engine import RealPQCCryptoEngine, CryptographicEngineMetadata

# Primary alias
PQCCryptoEngine = RealPQCCryptoEngine

__all__ = ["RealPQCCryptoEngine", "PQCCryptoEngine", "CryptographicEngineMetadata"]
