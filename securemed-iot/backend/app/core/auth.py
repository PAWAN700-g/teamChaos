"""Firebase Authentication & Token Verification for FastAPI.

Provides dependency injection for verifying Firebase ID tokens, extracting
user claims, and enforcing role-based access control (RBAC).
"""

from fastapi import Depends, HTTPException, Header, status
from typing import Optional, Dict, Any
import os

try:
    import firebase_admin
    from firebase_admin import auth, credentials
    _FIREBASE_ADMIN_AVAILABLE = True
except ImportError:
    _FIREBASE_ADMIN_AVAILABLE = False


def init_firebase_admin(service_account_path: Optional[str] = None):
    """Initialize Firebase Admin SDK if credentials are provided."""
    if not _FIREBASE_ADMIN_AVAILABLE:
        print("[Auth] firebase_admin package not installed. Using local prototype token verification.")
        return False

    if not firebase_admin._apps:
        if service_account_path and os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            print("[Auth] Firebase Admin initialized with service account.")
            return True
        else:
            print("[Auth] No Firebase service account path provided. Dev mode active.")
            return False
    return True


async def get_current_user(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    """Verify Firebase Bearer token and extract user identity and role.

    Header format: `Authorization: Bearer <FIREBASE_ID_TOKEN>`
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Authorization header. Expected 'Bearer <token>'.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split("Bearer ")[1].strip()

    # If Firebase Admin SDK is initialized, verify cryptographically with Google
    if _FIREBASE_ADMIN_AVAILABLE and firebase_admin._apps:
        try:
            decoded_token = auth.verify_id_token(token)
            return {
                "uid": decoded_token.get("uid"),
                "email": decoded_token.get("email", ""),
                "role": decoded_token.get("role", "doctor"),
                "token_claims": decoded_token,
            }
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid Firebase ID Token: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )

    # Prototype / Test token fallback (e.g. Bearer mock-token-doctor)
    if token.startswith("mock-"):
        parts = token.split("-")
        role = parts[1] if len(parts) > 1 else "doctor"
        return {
            "uid": f"user-{role}-001",
            "email": f"{role}@hospital.local",
            "role": role,
            "notice": "Mock token verified in prototype environment",
        }

    # Development fallback
    return {
        "uid": "dev-user-001",
        "email": "clinician@hospital.local",
        "role": "doctor",
        "token_preview": token[:16] + "...",
    }


def require_role(allowed_roles: list[str]):
    """Enforce that the authenticated user possesses one of the allowed roles."""
    async def role_checker(user: Dict[str, Any] = Depends(get_current_user)):
        user_role = user.get("role", "doctor")
        if user_role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: Role '{user_role}' does not have sufficient permissions. Required: {allowed_roles}",
            )
        return user
    return role_checker
