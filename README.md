# Team Chaos - SecureMed IoT

**SecureMed IoT** is a next-generation cybersecurity platform designed to protect connected hospital patient-monitoring devices against both classical cyberattacks and future quantum threats using Post-Quantum Cryptography (PQC), authenticated encryption, device identity verification, and real-time attack anomaly detection.

> [!CAUTION]
> **CRITICAL DISCLAIMER**: SecureMed IoT is an educational and hackathon cybersecurity prototype. All medical devices are simulated and all patient metrics are synthetic. Never connect this prototype to real medical equipment or make clinical decisions based on its data. SecureMed IoT does not claim regulatory compliance (e.g., FDA 510(k), HIPAA certification, or MDR CE-mark) or production medical-device readiness.

---

## Architecture & Technology Mapping

| Module | Main Technology | Security Standard / Implementation |
| :--- | :--- | :--- |
| **Login & Registration** | Flutter + Firebase Auth | Multi-role authentication & token verification |
| **Server-Side RBAC** | FastAPI + Cloud Firestore | Enforces roles from server-side database records |
| **Device Registration** | FastAPI + Firestore | Public key registration; private keys strictly forbidden |
| **Device Authentication** | ML-DSA-65 | NIST FIPS 204 (Post-Quantum Digital Signatures) |
| **Secure Key Establishment** | ML-KEM-768 | NIST FIPS 203 (Post-Quantum Key Encapsulation) |
| **Telemetry Encryption** | AES-256-GCM | NIST SP 800-38D Authenticated Encryption with AAD |
| **Key Derivation** | HKDF-SHA-256 | RFC 5869 Ephemeral Session Key Derivation |
| **Live Patient Dashboard** | Flutter + Cloud Firestore | Material 3 interface streaming verified telemetry |
| **Replay Attack Defense** | FastAPI Gateway | Monotonic sequence counters & freshness window |
| **Fake-Device Defense** | FastAPI + ML-DSA-65 | Identity attestation against pre-registered registry |
| **Telemetry Tampering Defense** | AES-256-GCM | 128-bit GHASH authentication tag verification |
| **Firmware Integrity & Anti-Rollback** | ML-DSA-65 + SHA-256 | Pre-provisioned vendor keystore & semver anti-rollback |
| **Tamper-Evident Audit Logs** | SHA-256 Hash Chaining | Immutable parent-hash linked ledger & verify endpoint |
| **External Anchoring** | SHA-256 Anchoring Digest | Exports latest head digest for external ledger publication |
| **Attack Simulation Suite** | Flutter + FastAPI | 8 hostile threat vectors with real-time detection |
| **Device Fleet Simulation** | Python Async Client | Synthetic vitals (ECG, Heart Rate, SpO2) |

---

## Monorepo Layout

The complete **SecureMed IoT** codebase is organized cleanly inside [`securemed-iot/`](./securemed-iot/):

- 📱 **Frontend**: [`securemed-iot/frontend/`](./securemed-iot/frontend/) (Flutter + Material 3 + Android & Chrome ready, 27 test cases)
- 🔒 **Backend**: [`securemed-iot/backend/`](./securemed-iot/backend/) (FastAPI + PQC Cryptographic Engine + Firestore Service, 43 test cases)
- 🩺 **Device Simulator**: [`securemed-iot/device_simulator/`](./securemed-iot/device_simulator/) (Synthetic Medical Device Telemetry Generator, 12 test cases)
- 📚 **Docs**: [`securemed-iot/docs/`](./securemed-iot/docs/) (Architecture, Roadmap, and Cryptographic Protocols)
- ⚡ **Scripts**: [`securemed-iot/scripts/`](./securemed-iot/scripts/) (Cross-platform PowerShell automation scripts)
- 🛡️ **Rules**: [`securemed-iot/firestore.rules`](./securemed-iot/firestore.rules) (Production Cloud Firestore Security Rules)

---

## ⚡ Quick Start Instructions

Both backend and frontend run out-of-the-box locally in zero-config development mode.

### 1. Start Backend (FastAPI Gateway)
```bash
cd securemed-iot/backend
.\.venv\Scripts\python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
*Gateway API Documentation*: [http://localhost:8000/docs](http://localhost:8000/docs)  
*Health Status*: [http://localhost:8000/api/v1/health](http://localhost:8000/api/v1/health)

### 2. Start Frontend (Flutter Dashboard)
```bash
cd securemed-iot/frontend
flutter run -d chrome    # or: flutter run -d android
```

### 3. Start Medical Device Fleet Simulator
```bash
cd securemed-iot/device_simulator
..\backend\.venv\Scripts\python simulator.py --devices all --interval 3.0
```

### 4. Execute Complete Automated Test Suites (82 Tests)
```bash
# Run backend pytest suite (43 tests):
cd securemed-iot/backend
.\.venv\Scripts\python -m pytest -v

# Run simulator test suite (12 tests):
cd securemed-iot/device_simulator
..\backend\.venv\Scripts\python -m pytest -v

# Run frontend flutter test suite (27 tests):
cd securemed-iot/frontend
flutter test
```

---

## 🎯 Hackathon Demonstration Script

Follow these steps during live judging:

1. **User Authentication & Role Scoping**:
   - Log in as **Doctor** (`doctor@hospital.local` / `Password123!`). View assigned patient telemetry. Notice administrative actions (device revocation) are restricted.
   - Switch to **Administrator** (`admin@hospital.local` / `Password123!`). Notice elevated management permissions.
2. **Post-Quantum Device Fleet Handshake**:
   - In the "Devices" tab, view connected fleet: `MED-DEV-ICU-701A`, `MED-DEV-INF-412C`, `MED-DEV-VENT-901B`.
   - Inspect active cryptographic status: ML-KEM-768 session keys, ML-DSA-65 identities, AES-256-GCM encryption.
3. **Interactive Attack Simulation**:
   - Navigate to the **Simulation** tab and trigger the 8 cybersecurity test vectors:
     - **Attack 1 (Device Impersonation)**: Unregistered rogue device fails identity lookup (`404 Not Found`).
     - **Attack 2 (Replay Attack)**: Duplicate sequence packet dropped (`400 Bad Request`).
     - **Attack 3 (Telemetry Tampering)**: Bit-flipped ciphertext fails GHASH tag verification (`400 Bad Request`).
     - **Attack 4 (Unauthorized Access)**: Doctor attempting Admin revocation blocked (`403 Forbidden`).
     - **Attack 5 (Firmware Tampering)**: Altered binary fails ML-DSA-65 signature check (`400 Bad Request`).
     - **Attack 6 (Rate Limit Test)**: High-frequency burst throttled (`429 Too Many Requests`).
     - **Attack 7 (Device Revocation)**: Revoked device blocked from session handshake (`403 Forbidden`).
     - **Attack 8 (Audit Modification)**: Corrupted record detected by SHA-256 hash chaining (`400 Bad Request`).
4. **Security Center & Firmware Attestation**:
   - View SIEM alert severity breakdown (Critical, High, Medium, Low).
   - In the **Firmware Security & Anti-Rollback** card, click **Verify Package** to attest genuine firmware against the Trusted Vendor Keystore.
   - Click **Test Rollback Block** to demonstrate anti-rollback defense blocking version downgrade (`v1.5.0` < `v2.0.0`).
5. **Tamper-Evident Audit Ledger & External Anchoring**:
   - Open **Audit Logs** tab. Click **Verify Chain** to cryptographically verify hash-chain continuity.
   - Click **Export Anchor** to inspect the SHA-256 anchoring digest and review the documented limitation regarding full-database recomputation.

For technical details, see [`securemed-iot/README.md`](./securemed-iot/README.md).
