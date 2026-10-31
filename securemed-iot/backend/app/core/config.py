from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")

    PROJECT_NAME: str = "SecureMed IoT Gateway"
    VERSION: str = "0.1.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # Server Configuration
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # CORS
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080,http://127.0.0.1:8080,http://localhost:5000"

    # Security & Cryptography
    SECRET_KEY: str = "insecure-hackathon-secret-key-change-in-production"
    PQC_ALGORITHM_KEM: str = "ML-KEM-768"
    PQC_ALGORITHM_DSA: str = "ML-DSA-65"
    SYMMETRIC_CIPHER: str = "AES-256-GCM"

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = ""
    FIREBASE_PROJECT_ID: str = "securemed-iot-demo"

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]


settings = Settings()
