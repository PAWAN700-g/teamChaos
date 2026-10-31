from fastapi import APIRouter
from app.core.config import settings

router = APIRouter()


@router.get("/health", summary="System Health & Security Status")
async def health_check():
    """Returns the operational status of the SecureMed IoT platform and cryptographic engine."""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "cryptography": {
            "kem_algorithm": settings.PQC_ALGORITHM_KEM,
            "dsa_algorithm": settings.PQC_ALGORITHM_DSA,
            "symmetric_cipher": settings.SYMMETRIC_CIPHER,
            "nist_standards": ["FIPS 203 (ML-KEM)", "FIPS 204 (ML-DSA)"],
            "status": "operational",
        },
        "disclaimer": (
            "HACKATHON PROTOTYPE ONLY: Simulated medical devices & synthetic patient data. "
            "Never connect to live clinical hardware or use for patient treatment."
        ),
    }
