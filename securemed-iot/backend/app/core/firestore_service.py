"""SecureMed IoT - Firestore Integration Service (Backend Authority).

FastAPI acts as the trusted backend security authority:
1. Only the backend (via Firebase Admin SDK) writes verified telemetry and security alerts.
2. Device telemetry is authenticated and decrypted before it is published to Firestore.
3. Invalid, replayed, or tampered telemetry is rejected before touching Firestore.
4. Client SDKs cannot write directly to verified telemetry or security alert collections.
5. In offline/prototype environments without GCP credentials, an in-memory mock store
   ensures seamless local execution and complete testability.
"""

from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
import uuid
import os

try:
    import firebase_admin
    from firebase_admin import firestore
    _FIREBASE_AVAILABLE = True
except ImportError:
    _FIREBASE_AVAILABLE = False


class FirestoreService:
    """Service for publishing authenticated data to Cloud Firestore."""

    def __init__(self):
        self._db = None
        self._is_mock = True
        # In-memory mock store for local development and offline test suites
        self._mock_collections: Dict[str, Dict[str, Dict[str, Any]]] = {
            "users": {},
            "devices": {},
            "telemetry": {},
            "security_alerts": {},
            "dashboard_summaries": {
                "current": {
                    "total_devices": 0,
                    "online_devices": 0,
                    "offline_devices": 0,
                    "active_alerts": 0,
                    "latest_heart_rate": 72,
                    "latest_spo2": 98,
                    "last_updated": datetime.now(timezone.utc).isoformat(),
                    "is_simulated": True,
                }
            },
        }

    def initialize(self, service_account_path: Optional[str] = None):
        """Initialize Firestore client using Firebase Admin SDK."""
        if not _FIREBASE_AVAILABLE:
            print("[FirestoreService] firebase_admin not available; running with in-memory store.")
            self._is_mock = True
            return

        try:
            if firebase_admin._apps:
                self._db = firestore.client()
                self._is_mock = False
                print("[FirestoreService] Connected to Cloud Firestore via Firebase Admin SDK.")
            elif service_account_path and os.path.exists(service_account_path):
                # Init will have happened or can happen here
                self._db = firestore.client()
                self._is_mock = False
                print(f"[FirestoreService] Initialized Firestore from service account: {service_account_path}")
            else:
                self._is_mock = True
                print("[FirestoreService] Running with in-memory mock store (no credentials path provided).")
        except Exception as e:
            print(f"[FirestoreService] Could not connect to Cloud Firestore ({e}). Using mock store.")
            self._is_mock = True

    @property
    def is_connected_to_cloud(self) -> bool:
        return not self._is_mock and self._db is not None

    # ------------------------------------------------------------------
    # User Profile & Role Verification (Server-Side Authority)
    # ------------------------------------------------------------------

    async def get_user_role(self, uid: str) -> Optional[str]:
        """Fetch trusted server-side user role from Firestore."""
        if self._is_mock:
            user_doc = self._mock_collections["users"].get(uid)
            return user_doc.get("role") if user_doc else None

        try:
            doc_ref = self._db.collection("users").document(uid)
            snapshot = doc_ref.get()
            if snapshot.exists:
                return snapshot.to_dict().get("role")
            return None
        except Exception as e:
            print(f"[FirestoreService] Error fetching user role for {uid}: {e}")
            return None

    async def set_user_profile(self, uid: str, profile_data: Dict[str, Any]):
        """Create or update user profile with server-verified role."""
        profile_data["updated_at"] = datetime.now(timezone.utc).isoformat()
        if self._is_mock:
            self._mock_collections["users"][uid] = profile_data
            return

        try:
            self._db.collection("users").document(uid).set(profile_data, merge=True)
        except Exception as e:
            print(f"[FirestoreService] Error writing user profile {uid}: {e}")

    # ------------------------------------------------------------------
    # Device Registration & Revocation Metadata
    # ------------------------------------------------------------------

    async def publish_device(self, device_id: str, device_data: Dict[str, Any]):
        """Publish registered device metadata to Firestore."""
        data = {
            **device_data,
            "device_id": device_id,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        if self._is_mock:
            self._mock_collections["devices"][device_id] = data
            self._recalculate_summary()
            return

        try:
            self._db.collection("devices").document(device_id).set(data, merge=True)
            await self._update_cloud_dashboard_summary()
        except Exception as e:
            print(f"[FirestoreService] Error publishing device {device_id}: {e}")

    async def mark_device_revoked(self, device_id: str, reason: str = "Backend security enforcement"):
        """Record device revocation in Firestore so clients see revoked status."""
        update_data = {
            "status": "revoked",
            "revoked_at": datetime.now(timezone.utc).isoformat(),
            "revocation_reason": reason,
        }
        if self._is_mock:
            if device_id in self._mock_collections["devices"]:
                self._mock_collections["devices"][device_id].update(update_data)
                self._recalculate_summary()
            return

        try:
            self._db.collection("devices").document(device_id).set(update_data, merge=True)
            await self._update_cloud_dashboard_summary()
        except Exception as e:
            print(f"[FirestoreService] Error marking device revoked {device_id}: {e}")

    # ------------------------------------------------------------------
    # Verified Telemetry Publishing (Only called AFTER PQC Verification)
    # ------------------------------------------------------------------

    async def publish_verified_telemetry(self, telemetry_data: Dict[str, Any]) -> str:
        """
        Publishes decrypted and authenticated telemetry packet to Firestore.
        CRITICAL: This is only invoked AFTER AES-256-GCM authentication tag
        and ML-DSA-65 signature have been verified by the backend.
        """
        telemetry_id = f"TEL-{uuid.uuid4().hex[:12].upper()}"
        data = {
            **telemetry_data,
            "telemetry_id": telemetry_id,
            "published_at": datetime.now(timezone.utc).isoformat(),
            "is_simulated": True,  # Explicit safety watermark
            "is_verified_by_backend": True,
        }

        device_id = telemetry_data.get("device_id")

        if self._is_mock:
            self._mock_collections["telemetry"][telemetry_id] = data
            if device_id and device_id in self._mock_collections["devices"]:
                self._mock_collections["devices"][device_id]["last_seen"] = data["published_at"]
                self._mock_collections["devices"][device_id]["status"] = "active"

            # Update latest vitals in summary
            vitals = telemetry_data.get("vitals", {})
            if "heart_rate_bpm" in vitals:
                self._mock_collections["dashboard_summaries"]["current"]["latest_heart_rate"] = vitals["heart_rate_bpm"]
            if "spo2_percent" in vitals:
                self._mock_collections["dashboard_summaries"]["current"]["latest_spo2"] = vitals["spo2_percent"]
            self._recalculate_summary()
            return telemetry_id

        try:
            self._db.collection("telemetry").document(telemetry_id).set(data)
            if device_id:
                self._db.collection("devices").document(device_id).set({
                    "last_seen": data["published_at"],
                    "status": "active",
                }, merge=True)
            await self._update_cloud_dashboard_summary(latest_vitals=telemetry_data.get("vitals"))
            return telemetry_id
        except Exception as e:
            print(f"[FirestoreService] Error publishing telemetry: {e}")
            return telemetry_id

    # ------------------------------------------------------------------
    # Security Alerts Publishing (Generated by Backend Detection Logic)
    # ------------------------------------------------------------------

    async def publish_security_alert(self, alert_data: Dict[str, Any]) -> str:
        """Publishes detected attack or security incident to Firestore."""
        alert_id = alert_data.get("alert_id") or f"ALT-{uuid.uuid4().hex[:10].upper()}"
        data = {
            **alert_data,
            "alert_id": alert_id,
            "detected_by": "FastAPI_PQC_Security_Authority",
            "published_at": datetime.now(timezone.utc).isoformat(),
            "resolved": False,
        }

        if self._is_mock:
            self._mock_collections["security_alerts"][alert_id] = data
            self._recalculate_summary()
            return alert_id

        try:
            self._db.collection("security_alerts").document(alert_id).set(data)
            await self._update_cloud_dashboard_summary()
            return alert_id
        except Exception as e:
            print(f"[FirestoreService] Error publishing security alert: {e}")
            return alert_id

    # ------------------------------------------------------------------
    # Dashboard Summaries
    # ------------------------------------------------------------------

    def get_dashboard_summary(self) -> Dict[str, Any]:
        """Returns the current aggregated dashboard summary."""
        if self._is_mock:
            return self._mock_collections["dashboard_summaries"]["current"]

        try:
            doc = self._db.collection("dashboard_summaries").document("current").get()
            if doc.exists:
                return doc.to_dict()
        except Exception as e:
            print(f"[FirestoreService] Error fetching summary from Firestore: {e}")

        return self._mock_collections["dashboard_summaries"]["current"]

    def _recalculate_summary(self):
        """Internal helper to recalculate mock dashboard metrics."""
        devices = self._mock_collections["devices"]
        total = len(devices)
        active = sum(1 for d in devices.values() if d.get("status") == "active")
        revoked = sum(1 for d in devices.values() if d.get("status") == "revoked")
        alerts = len(self._mock_collections["security_alerts"])

        curr = self._mock_collections["dashboard_summaries"]["current"]
        curr["total_devices"] = total
        curr["online_devices"] = active
        curr["offline_devices"] = revoked
        curr["active_alerts"] = alerts
        curr["last_updated"] = datetime.now(timezone.utc).isoformat()

    async def _update_cloud_dashboard_summary(self, latest_vitals: Optional[Dict[str, Any]] = None):
        """Update Firestore document /dashboard_summaries/current."""
        try:
            devices_ref = self._db.collection("devices")
            total = len(list(devices_ref.stream()))
            active = len(list(devices_ref.where("status", "==", "active").stream()))
            revoked = len(list(devices_ref.where("status", "==", "revoked").stream()))

            alerts_ref = self._db.collection("security_alerts")
            unresolved_alerts = len(list(alerts_ref.where("resolved", "==", False).stream()))

            summary = {
                "total_devices": total,
                "online_devices": active,
                "offline_devices": revoked,
                "active_alerts": unresolved_alerts,
                "last_updated": datetime.now(timezone.utc).isoformat(),
                "is_simulated": True,
            }
            if latest_vitals:
                if "heart_rate_bpm" in latest_vitals:
                    summary["latest_heart_rate"] = latest_vitals["heart_rate_bpm"]
                if "spo2_percent" in latest_vitals:
                    summary["latest_spo2"] = latest_vitals["spo2_percent"]

            self._db.collection("dashboard_summaries").document("current").set(summary, merge=True)
        except Exception as e:
            print(f"[FirestoreService] Could not update cloud summary: {e}")


# Global singleton instance
firestore_service = FirestoreService()
