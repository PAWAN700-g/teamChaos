# Team Chaos - SecureMed IoT

**SecureMed IoT** is a next-generation cybersecurity platform designed to protect connected hospital patient-monitoring devices against both classical cyberattacks and future quantum threats using Post-Quantum Cryptography (PQC), authenticated encryption, device identity verification, and real-time attack anomaly detection.

> **CRITICAL DISCLAIMER**: SecureMed IoT is an educational and hackathon cybersecurity prototype. All medical devices are simulated and all patient metrics are synthetic. Never connect this prototype to real medical equipment or make clinical decisions based on its data.

---

## Architecture & Technology Mapping

| Module | Main Technology |
| :--- | :--- |
| **Login and registration** | Flutter + Firebase Auth |
| **User roles** | Firebase + FastAPI |
| **Device registration** | FastAPI + Firestore |
| **Device authentication** | ML-DSA-65 (NIST FIPS 204) |
| **Secure key establishment** | ML-KEM-768 (NIST FIPS 203) |
| **Telemetry encryption** | AES-256-GCM (NIST SP 800-38D) |
| **Live patient dashboard** | Flutter + Firestore |
| **Replay attack detection** | FastAPI (Monotonic Sequence Tracker) |
| **Fake-device detection** | FastAPI + ML-DSA-65 |
| **Telemetry tampering detection** | AES-256-GCM Tag Verification |
| **Firmware verification** | ML-DSA-65 + SHA-256 Fingerprint |
| **Unauthorized access prevention** | Firebase Auth + FastAPI RBAC |
| **Audit logs** | FastAPI + Firestore + SHA-256 Hash Chaining |
| **Attack simulation** | Flutter + FastAPI |
| **Device simulation** | Python (Synthetic Medical Telemetry) |

---

## Monorepo Layout

The complete **SecureMed IoT** codebase is organized cleanly inside [`securemed-iot/`](./securemed-iot/):

- 📱 **Frontend**: [`securemed-iot/frontend/`](./securemed-iot/frontend/) (Flutter + Material 3 + Android APK ready)
- 🔒 **Backend**: [`securemed-iot/backend/`](./securemed-iot/backend/) (FastAPI + PQC Cryptographic Security Engine)
- 🩺 **Device Simulator**: [`securemed-iot/device_simulator/`](./securemed-iot/device_simulator/) (Synthetic Medical Device Telemetry Generator)
- 📚 **Docs**: [`securemed-iot/docs/`](./securemed-iot/docs/) (Architecture, Roadmap, and Cryptographic Protocols)
- ⚡ **Scripts**: [`securemed-iot/scripts/`](./securemed-iot/scripts/) (Cross-platform PowerShell automation scripts)

---

## Quick Start & Verification

### Run Backend
```bash
cd securemed-iot/backend
uvicorn main:app --reload --port 8000
```

### Run Device Simulator
```bash
cd securemed-iot/device_simulator
python simulator.py
```

### Run Frontend
```bash
cd securemed-iot/frontend
flutter run
```

### Execute Test Suites
```bash
# Backend pytest suite (19 tests)
cd securemed-iot/backend
pytest -v

# Frontend test suite (9 tests)
cd securemed-iot/frontend
flutter test
```

For complete instructions and detailed API guides, refer to [`securemed-iot/README.md`](./securemed-iot/README.md) and [`securemed-iot/docs/cryptographic_protocol.md`](./securemed-iot/docs/cryptographic_protocol.md).
