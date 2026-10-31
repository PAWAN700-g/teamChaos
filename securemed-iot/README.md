# SecureMed IoT 🛡️🏥

> **Post-Quantum Cybersecurity Platform for Connected Hospital Patient-Monitoring Devices**  
> *Developed by Team Chaos for Hackathon Prototype Demonstration*

---

> [!CAUTION]
> **HACKATHON PROTOTYPE ONLY**: SecureMed IoT utilizes simulated medical devices and synthetic patient physiological data only. It is explicitly engineered for cybersecurity research, cryptographic benchmarking, and hackathon demonstration. **Never connect this software to live medical equipment or rely upon it for clinical decision-making.**

---

## 📖 Overview

Modern hospital networks host thousands of connected Internet of Medical Things (IoMT) devices—including multiparameter ICU monitors, infusion pumps, and ambulatory telemetry sensors. Most rely on legacy cryptographic standards (such as RSA-2048 or classical ECDH/ECDSA) that are vulnerable to **Harvest-Now, Decrypt-Later (HNDL)** quantum eavesdropping and network impersonation attacks.

**SecureMed IoT** establishes a post-quantum cryptographic security layer for healthcare devices:
1. **Post-Quantum Key Exchange**: Implements NIST FIPS 203 **ML-KEM-768** (Kyber) for quantum-resistant session key negotiation.
2. **Device Identity & Attestation**: Employs NIST FIPS 204 **ML-DSA-65** (Dilithium) to sign telemetry streams and authenticate device identities.
3. **High-Throughput Authenticated Encryption**: Derives 256-bit ephemeral keys via **HKDF-SHA-256** and secures patient telemetry with **AES-256-GCM**.
4. **Cyber Threat & Anomaly Detection**: Identifies unauthorized spoofed devices, replay attacks, and telemetry tampering in real time.
5. **Modern Clinical Dashboard**: A Flutter Material 3 monitoring console visualizing device fleet health, cryptographic statuses, and live synthetic vitals.

---

## 🏗️ Monorepo Architecture

```
securemed-iot/
├── frontend/             # Flutter + Dart + Material 3 Clinical Dashboard
│   ├── lib/              # Application entrypoint & UI components
│   ├── test/             # Flutter widget test suite
│   ├── pubspec.yaml      # Flutter package specifications
│   └── .env.example      # Frontend environment template
├── backend/              # Python + FastAPI Gateway & PQC Engine
│   ├── app/
│   │   ├── core/         # Config & PQC Cryptographic Engine (ML-KEM, ML-DSA)
│   │   └── api/v1/       # REST & WebSocket endpoints (Health, Crypto, Devices)
│   ├── tests/            # Pytest suite for API and crypto primitives
│   ├── requirements.txt  # Python pip dependencies
│   ├── pyproject.toml    # Modern Python packaging configuration
│   └── .env.example      # Backend environment template
├── device_simulator/     # Python Medical IoT Simulation Client
│   ├── simulator.py      # Standalone CLI simulator for PQC device lifecycle
│   ├── models.py         # Synthetic patient telemetry data models
│   ├── config.py         # Simulator settings
│   └── .env.example      # Device simulator environment template
├── docs/                 # System Architecture & Development Specifications
│   ├── architecture.md   # Architectural design, crypto flows, threat model
│   └── roadmap.md        # Phased development roadmap (Phases 1-7)
├── scripts/              # Developer convenience & automation scripts
│   ├── run_backend.bat   # Windows Batch runner for FastAPI
│   ├── run_backend.ps1   # PowerShell runner for FastAPI
│   ├── run_frontend.bat  # Windows Batch runner for Flutter
│   ├── run_frontend.ps1  # PowerShell runner for Flutter
│   ├── run_simulator.bat # Windows Batch runner for Device Simulator
│   ├── run_simulator.ps1 # PowerShell runner for Device Simulator
│   ├── run_all_tests.bat # Windows Batch unified test runner
│   └── run_all_tests.ps1 # PowerShell unified test runner
├── .env.example          # Monorepo-level environment variable template
├── .gitignore            # Git ignore rules for Python, Flutter, and credentials
└── README.md             # Project documentation (this file)
```

---

## ⚡ Quick Start Guide

### 1. Prerequisites
- **Python**: 3.11+ (Python 3.14 verified)
- **Flutter**: 3.44+ (Channel stable)
- **Dart**: 3.12+
- **Chrome / Web Browser** (or Android Emulator / Windows C++ build tools)

---

### 2. Run Backend (FastAPI Gateway)

```bash
# Navigate to backend
cd securemed-iot/backend

# Activate the virtual environment
.venv\Scripts\activate       # Windows PowerShell: .venv\Scripts\Activate.ps1

# Run the API gateway with auto-reload
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
*API Swagger Documentation*: [http://localhost:8000/docs](http://localhost:8000/docs)  
*Health & Crypto Status*: [http://localhost:8000/api/v1/health](http://localhost:8000/api/v1/health)

---

### 3. Run Frontend (Flutter Dashboard)

```bash
# Navigate to frontend
cd securemed-iot/frontend

# Launch on Chrome
flutter run -d chrome
```

---

### 4. Run Android App (Device / Emulator)

```bash
# Navigate to frontend
cd securemed-iot/frontend

# Run on connected Android device or emulator
flutter run -d android

# Or build the standalone debug APK:
flutter build apk --debug
# Output: securemed-iot/frontend/build/app/outputs/flutter-apk/app-debug.apk
```

*Or use the runner script:*
```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android.ps1
```

---

### 5. Run Medical Device Fleet Simulator

```bash
# Navigate to device simulator
cd securemed-iot/device_simulator

# 1. Run all 3 simulated medical devices (ECG, Heart Rate, SpO2):
..\backend\.venv\Scripts\python simulator.py --devices all

# 2. Run a specific device continuously (e.g. 12-Lead ECG monitor with 3s intervals):
..\backend\.venv\Scripts\python simulator.py --devices ecg --interval 3.0 --count 0

# 3. Simulate an attack (replay attack, MITM ciphertext tampering, or signature forgery):
..\backend\.venv\Scripts\python simulator.py --devices spo2 --attack replay --count 2

# 4. Run the automated cybersecurity & cryptographic verification suite:
..\backend\.venv\Scripts\python simulator.py --verify
```

---

### 6. Run All Unit & Security Tests

```bash
# Run Backend Pytest, Simulator Security Verification, and Frontend Flutter tests:
powershell -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1
```

Or run individually:
```bash
# Backend & Simulator tests (31 test cases verifying PQC, replay, and telemetry):
cd securemed-iot
backend\.venv\Scripts\python -m pytest backend/tests device_simulator/test_simulator.py -v

# Frontend Flutter tests (11 test cases verifying responsive UI, tabs, and auth):
cd securemed-iot/frontend
flutter test
```

---

## 🔐 Cryptography Specifications

| Function | Standard | Key/Tag Length | Purpose |
| :--- | :--- | :--- | :--- |
| **KEM** | NIST FIPS 203 (ML-KEM-768) | 1,184 B (pub) / 1,088 B (ct) | Post-quantum session secret exchange |
| **DSA** | NIST FIPS 204 (ML-DSA-65) | 1,952 B (pub) / 3,309 B (sig) | Quantum-safe mutual device authentication |
| **KDF** | RFC 5869 (HKDF-SHA-256) | 256-bit symmetric key | Derivation of ephemeral telemetry keys |
| **AEAD** | NIST SP 800-38D (AES-256-GCM) | 256-bit key, 96-bit nonce | High-speed authenticated stream encryption |

---

## 🔥 Firebase & Cloud Firestore Integration

SecureMed IoT integrates **Firebase Authentication** for identity management and **Cloud Firestore** for secure data persistence with role-based access control (RBAC).

### 1. Security Architecture & Principles
- **Zero-Trust Role Enforcement**: User roles are never trusted from Flutter client code alone. All authorization is validated via Firestore Security Rules and verified in backend endpoints via the Firebase Admin SDK.
- **Admin Self-Assignment Prevention**: Users can never assign themselves the `admin` role upon registration. All self-registered accounts default to an unprivileged role (`doctor` or `security_analyst`). Elevating an account to `admin` requires modification by an existing system administrator.
- **Cryptographic Key Isolation**: Firestore Security Rules strictly prohibit storing cryptographic private keys (`privateKey`, `private_key`, `secretKey`, etc.) in the database.
- **Immutable Audit Trail**: Telemetry packets and audit events are strictly append-only. Firestore Security Rules deny `update` and `delete` operations on `/telemetry` and `/audit_events`.

### 2. Firestore Collection Schemas

| Collection | Document ID | Key Fields | Access Controls |
| :--- | :--- | :--- | :--- |
| **`users`** | `{userId}` (auth.uid) | `uid`, `email`, `displayName`, `role` (`admin`, `doctor`, `security_analyst`), `createdAt`, `updatedAt` | Read: Self + Admin/SecOps. Create: Self (no admin). Update: Self (role immutable for non-admin). Delete: Admin only. |
| **`devices`** | `{deviceId}` | `deviceId`, `deviceType`, `status`, `dsaPublicKeyB64`, `lastHeartbeat`, `registeredAt` | Read: Authenticated users. Write: Admin & SecOps only. Private keys strictly forbidden. |
| **`telemetry`** | `{telemetryId}` | `deviceId`, `timestamp`, `isEncrypted`, `ciphertextPreview`, `syntheticVitals`, `signatureB64` | Read: Authenticated users. Create: Ingestion service / Admin / SecOps. Updates & Deletes permanently denied. |
| **`security_alerts`** | `{alertId}` | `alertId`, `deviceId`, `timestamp`, `severity` (`info`, `warning`, `critical`), `attackType`, `description`, `resolved` | Read: All authenticated staff. Create: Authenticated. Update/Acknowledge: SecOps & Admin only. Delete: Admin only. |
| **`audit_events`** | `{eventId}` | `eventId`, `timestamp`, `eventType`, `actorUid`, `actorRole`, `details` | Read: Admin & SecOps only. Create: Authenticated (verified actor UID). Append-only immutability. |

### 3. Deploying Firestore Security Rules

To deploy the security rules to your Firebase project:

```bash
cd securemed-iot

# Log in to Firebase CLI (if not already logged in)
firebase login

# Select or switch to your Firebase project
firebase use <your-firebase-project-id>

# Deploy rules
firebase deploy --only firestore:rules
```

Or test locally using the Firebase Local Emulator Suite:
```bash
firebase emulators:start --only firestore,auth
```

### 4. Configuring FlutterFire

To connect a live Firebase project to the Flutter frontend:
1. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
2. Run configuration in `securemed-iot/frontend`:
   ```bash
   cd securemed-iot/frontend
   flutterfire configure --project=<your-firebase-project-id>
   ```
3. When running in offline or test mode without live Firebase credentials, the application automatically falls back to `MockAuthService` with simulated demo accounts:
   - **Doctor**: `doctor@hospital.local` / `Password123!`
   - **Security Analyst**: `analyst@hospital.local` / `Password123!`
   - **Administrator**: `admin@hospital.local` / `Password123!`

---

## 📜 Development Status
- **Phase 1**: Monorepo layout, baseline PQC engine, Material 3 Flutter dashboard, simulator CLI, and automated test runners are **operational**.
- **Phase 2**: Firebase Authentication, Firestore RBAC schemas, Firestore Security Rules (`firestore.rules`), route guards, and Riverpod/Provider state management are **operational**.
- For detailed upcoming milestones, see [`docs/roadmap.md`](docs/roadmap.md).
