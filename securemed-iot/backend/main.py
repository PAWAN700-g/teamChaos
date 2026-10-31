"""SecureMed IoT Gateway & Cryptographic Ingestion Server.

Cybersecurity platform protecting simulated hospital patient-monitoring devices
using Post-Quantum Cryptography (ML-KEM-768, ML-DSA-65) and AES-256-GCM.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.api.v1.router import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize PQC engine self-test
    print(f"[{settings.PROJECT_NAME}] Starting Post-Quantum Gateway...")
    print(f"[{settings.PROJECT_NAME}] PQC Algorithms: {settings.PQC_ALGORITHM_KEM}, {settings.PQC_ALGORITHM_DSA}")
    print(f"[{settings.PROJECT_NAME}] Prototype disclaimer: Synthetic patient data only.")
    yield
    print(f"[{settings.PROJECT_NAME}] Shutting down...")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Post-Quantum Cryptographic Healthcare IoT Security Platform",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Middleware (enabling dynamic localhost web ports and Android emulator 10.0.2.2)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.DEBUG else settings.cors_origins_list,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Routes
app.include_router(api_router, prefix="/api/v1")


@app.get("/", summary="Root Endpoint")
async def root():
    return {
        "message": "Welcome to SecureMed IoT Platform Gateway",
        "docs": "/docs",
        "api_v1": "/api/v1/health",
        "notice": "Simulated devices only. Hackathon cybersecurity prototype.",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
