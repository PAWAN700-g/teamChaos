from fastapi import APIRouter, HTTPException, Header, status
from pydantic import BaseModel, Field
from typing import List, Optional
import base64

from app.core.session_manager import security_manager
from app.core.firestore_service import firestore_service
from app.core.auth import get_current_user

router = APIRouter()


class DeviceRegistrationRequest(BaseModel):
    device_id: str = Field(..., json_schema_extra={"example": "MED-DEV-ICU-701A"})
    device_type: str = Field(..., json_schema_extra={"example": "ICU Vital Signs Monitor"})
    dsa_public_key_b64: str = Field(..., description="ML-DSA-65 1,952-byte public key in base64")


class DeviceRevocationRequest(BaseModel):
    reason: str = Field(default="Security compromise or decommissioning")


class DeviceResponse(BaseModel):
    device_id: str
    device_type: str
    status: str
    is_pqc_secured: bool
    dsa_public_key_b64: str
    registered_at: str
    revoked_at: Optional[str] = None


@router.post("/register", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED, summary="Register Medical Device")
async def register_device(req: DeviceRegistrationRequest):
    """Registers a medical device's ML-DSA-65 identity public key. Never returns or stores private keys."""
    try:
        raw_key = base64.b64decode(req.dsa_public_key_b64)
        if len(raw_key) != 1952:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid ML-DSA-65 public key size. Expected exactly 1,952 bytes, got {len(raw_key)} bytes.",
            )

        record = security_manager.register_device(
            device_id=req.device_id,
            device_type=req.device_type,
            dsa_public_key_raw=raw_key,
        )
        await firestore_service.publish_device(req.device_id, record.to_dict())
        return DeviceResponse(**record.to_dict())
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Device registration failed: {str(e)}")


@router.get("/", response_model=List[DeviceResponse], summary="List Medical Devices")
async def list_devices():
    """Retrieve all registered medical devices and their security status."""
    return [DeviceResponse(**d.to_dict()) for d in security_manager.devices.values()]


@router.get("/{device_id}", response_model=DeviceResponse, summary="Get Device Details")
async def get_device(device_id: str):
    device = security_manager.get_device(device_id)
    if not device:
        raise HTTPException(status_code=404, detail=f"Device '{device_id}' not found")
    return DeviceResponse(**device.to_dict())


@router.post("/{device_id}/revoke", response_model=DeviceResponse, summary="Revoke Device Credentials")
async def revoke_device(
    device_id: str,
    req: Optional[DeviceRevocationRequest] = None,
    authorization: Optional[str] = Header(None),
):
    """Revokes device credentials and invalidates all active cryptographic sessions. Requires ADMIN role when authenticated."""
    if authorization:
        user = await get_current_user(authorization)
        if user.get("role") != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: Admin privilege required to revoke devices. Current role: {user.get('role')}",
            )

    reason = req.reason if req else "Security compromise or decommissioning"
    success = security_manager.revoke_device(device_id, reason=reason)
    if not success:
        raise HTTPException(status_code=404, detail=f"Device '{device_id}' not found")
    await firestore_service.mark_device_revoked(device_id, reason=reason)
    device = security_manager.get_device(device_id)
    return DeviceResponse(**device.to_dict())
