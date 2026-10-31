from fastapi import APIRouter
from app.api.v1.endpoints import health, crypto, devices, telemetry, firmware, simulation

api_router = APIRouter()

api_router.include_router(health.router, tags=["Health"])
api_router.include_router(crypto.router, prefix="/crypto", tags=["Cryptography"])
api_router.include_router(devices.router, prefix="/devices", tags=["Devices"])
api_router.include_router(telemetry.router, prefix="/telemetry", tags=["Telemetry"])
api_router.include_router(firmware.router, prefix="/firmware", tags=["Firmware"])
api_router.include_router(simulation.router, prefix="/simulation", tags=["Simulation"])
