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

## 🏗️ Monorepo Architecture & Integration

```
Architecture Flow:
Flutter Client  ──(Bearer Firebase ID Token)──>  FastAPI Gateway (Trusted Authority)
     │                                                   │
     │                                     ┌─────────────┴─────────────┐
(Listens to authorized                     │                           │
 Firestore Collections)            Firebase Admin SDK           PQC Security Engine
     ▲                                     │                   (ML-KEM-768, ML-DSA-65)
     │                                     ▼                           ▲
     └───────────── Cloud Firestore ───────┘                           │
                     (Verified Telemetry, Alerts,              (AES-256-GCM Telemetry)
                      Device Fleet, Profiles)                          │
                                                                       │
                                                            Medical Device Simulator
                                                             (ECG, Heart Rate, SpO2)
```

```
securemed-iot/
├── frontend/             # Flutter + Dart + Material 3 Clinical Dashboard (9 Screens)
│   ├── lib/              # Application entrypoint, Repositories, Streams & UI
│   ├── test/             # Flutter widget test suite (19 test cases)
│   ├── pubspec.yaml      # Flutter package specifications (Dio, Provider, Firebase)
│   └── .env.example      # Frontend environment template
├── backend/              # Python + FastAPI Gateway, PQC Engine & Firestore Service
│   ├── app/
│   │   ├── core/         # PQC Engine, Auth, Session Manager, Firestore Service
│   │   └── api/v1/       # REST endpoints (Health, Crypto, Devices, Telemetry, Simulation)
│   ├── tests/            # Pytest suite (24 test cases for Crypto, RBAC, Integration)
│   ├── requirements.txt  # Python pip dependencies (firebase-admin, cryptography, etc.)
│   ├── pyproject.toml    # Modern Python packaging configuration
│   └── .env.example      # Backend environment template
├── device_simulator/     # Python Medical IoT Simulation Client
│   ├── simulator.py      # Standalone CLI simulator for PQC device lifecycle
│   ├── models.py         # Synthetic patient telemetry data models
│   ├── config.py         # Simulator settings
│   └── test_simulator.py # Simulator test suite (12 test cases)
├── docs/                 # System Architecture & Development Specifications
│   ├── architecture.md   # Architectural design, crypto flows, threat model
│   └── roadmap.md        # Phased development roadmap
├── scripts/              # Developer convenience & automation scripts
├── firestore.rules       # Cloud Firestore Security Rules (Zero-Trust RBAC & Lockdown)
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

### 6. Run All Unit & Security Tests (82 Tests Total)

```bash
# Backend Pytest (43 test cases verifying PQC, RBAC, Firmware, Audit, and Firestore):
cd securemed-iot/backend
.\.venv\Scripts\python -m pytest -v

# Device Simulator Pytest (12 test cases verifying synthetic telemetry & attacks):
cd securemed-iot/device_simulator
..\backend\.venv\Scripts\python -m pytest -v

# Frontend Flutter tests (27 test cases verifying 9-screen Material 3 UI & streams):
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
| **Hash Chain** | SHA-256 | 256-bit digest | Tamper-evident ledger & block chain verification |

---

## 🔥 Firebase & Cloud Firestore Integration

SecureMed IoT establishes a zero-trust post-quantum security model integrating **Firebase Authentication** for identity management, **Cloud Firestore** for data storage, and **FastAPI** as the central security authority.

### 1. Security Architecture & Invariants
- **Backend Security Authority**: FastAPI is the single source of truth for cryptographic validation. Device telemetry is decrypted and validated (PQC signature, sequence monotonicity, timestamp freshness, and GCM tag) **before** it is published to Firestore.
- **Client Write Lockdown**: Flutter clients can **never** write directly to `/telemetry`, `/security_alerts`, or `/dashboard_summaries` (`allow write: if false;`). Only the trusted backend service using the Firebase Admin SDK writes verified telemetry and detection alerts.
- **Firebase Admin SDK Isolation**: The Firebase Admin SDK and service-account private keys reside strictly in the backend gateway environment. **No service account keys are ever bundled or stored in the Flutter mobile application.**
- **Server-Side Role Authority**: FastAPI verifies caller roles against server-side Firestore records (`/users/{uid}`), preventing client-tampered custom claims or stale tokens from elevating privileges.
- **Doctor-Scoped Access**: Clinicians can only read device records and telemetry streams for devices explicitly assigned to them (`assignedDoctorId`, `assignedDoctorUids`, or user `assignedDeviceIds`). Cybersecurity analysts and administrators maintain global fleet visibility.
- **Cryptographic Key Isolation**: Firestore Security Rules strictly prohibit storing cryptographic private keys (`privateKey`, `private_key`, `secretKey`, etc.) in the database.
- **Immutable Audit Trail**: Audit events and telemetry packets are strictly permanent. Update and delete operations are denied on `/telemetry`, `/security_alerts`, and `/audit_events`.

### 2. Firestore Collection Schemas

| Collection | Document ID | Key Fields | Access Controls |
| :--- | :--- | :--- | :--- |
| **`users`** | `{userId}` (auth.uid) | `uid`, `email`, `displayName`, `role` (`admin`, `doctor`, `security_analyst`), `assignedDeviceIds`, `createdAt`, `updatedAt` | Read: Self + Admin. Create: Self (unprivileged roles only). Update: Self (role immutable for non-admin). Delete: Admin only. |
| **`devices`** | `{deviceId}` | `deviceId`, `deviceType`, `status`, `dsaPublicKeyB64`, `assignedDoctorId`, `assignedDoctorUids`, `lastSeen`, `registeredAt` | Read: Assigned Doctor, Security Analyst, Admin. Write: Admin & Security Analyst only. Private keys forbidden. |
| **`telemetry`** | `{telemetryId}` | `deviceId`, `device_id`, `vitals`, `timestamp`, `pqc_signature_verified`, `is_simulated`, `published_at` | Read: Assigned Doctor, Security Analyst, Admin. **Write: Strictly backend authority only (`allow write: if false;`).** |
| **`security_alerts`** | `{alertId}` | `alertId`, `deviceId`, `severity` (`info`, `warning`, `critical`), `attackType`, `description`, `timestamp`, `resolved` | Read: Security Analyst & Admin only. **Write: Strictly backend authority only (`allow write: if false;`).** |
| **`dashboard_summaries`** | `current` | `total_devices`, `online_devices`, `offline_devices`, `active_alerts`, `latest_heart_rate`, `latest_spo2`, `last_updated`, `is_simulated` | Read: All authenticated staff. **Write: Strictly backend authority only (`allow write: if false;`).** |
| **`audit_events`** | `{eventId}` | `eventId`, `timestamp`, `eventType`, `actorUid`, `actorRole`, `details` | Read: Admin & Security Analyst. Create: Authenticated (verified actor UID). Append-only immutability. |

---

## 🛠️ Step-by-Step Setup Guide

### Mode A: Zero-Config Local Prototype (Ready Immediately)
Both the backend and Flutter frontend include built-in zero-config mock services that run instantly without requiring a GCP or Firebase cloud account:
1. **Start Backend**:
   ```bash
   cd securemed-iot/backend
   .\.venv\Scripts\python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
2. **Start Flutter App**:
   ```bash
   cd securemed-iot/frontend
   flutter run -d chrome    # or: flutter run -d android
   ```
3. **Log in with seeded accounts**:
   - **Doctor**: `doctor@hospital.local` / `Password123!`
   - **Security Analyst**: `analyst@hospital.local` / `Password123!`
   - **Administrator**: `admin@hospital.local` / `Password123!`

---

### Mode B: Production Firebase & Cloud Firestore Setup

#### 1. Backend Firebase Admin Configuration
1. Go to the [Firebase Console](https://console.firebase.google.com/) -> **Project Settings** -> **Service accounts**.
2. Click **Generate new private key** and download the JSON file.
3. Save the JSON file into a secure path outside of public version control (e.g., `securemed-iot/backend/service-account.json`).
4. Configure in `securemed-iot/backend/.env`:
   ```env
   FIREBASE_CREDENTIALS_PATH=service-account.json
   FIREBASE_PROJECT_ID=<your-firebase-project-id>
   ```

#### 2. Deploy Firestore Security Rules
```bash
cd securemed-iot
firebase login
firebase use <your-firebase-project-id>
firebase deploy --only firestore:rules
```

#### 3. Configure Flutter App for Firebase
```bash
cd securemed-iot/frontend
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

#### 4. Run the Medical Device Fleet Simulator
```bash
cd securemed-iot/device_simulator
..\backend\.venv\Scripts\python simulator.py --devices all --interval 4.0
```
Telemetry will be post-quantum encrypted, signed with ML-DSA-65, decrypted by FastAPI, published to Cloud Firestore, and streamed live to the Flutter Material 3 Dashboard!

---

## 🎯 Hackathon Demonstration Script

Follow this step-by-step procedure during the live hackathon presentation:

1. **Authentication & Multi-Role Scoping**:
   - Launch Flutter frontend: `flutter run -d chrome`.
   - Log in as **Doctor** (`doctor@hospital.local` / `Password123!`). View assigned patient vital metrics.
   - Notice device revocation is restricted for clinicians.
   - Switch to **Administrator** (`admin@hospital.local` / `Password123!`). Access elevated fleet controls.
2. **Post-Quantum Fleet Encryption**:
   - In "Devices" tab, view real-time fleet: `MED-DEV-ICU-701A`, `MED-DEV-INF-412C`, `MED-DEV-VENT-901B`.
   - Tap any device to view live synthetic ECG waveforms, SpO2, and Heart Rate charts with cryptographic attestation.
3. **Cybersecurity Threat Vector Simulation**:
   - Navigate to the **Simulation** tab.
   - Trigger the 8 hostile attacks:
     1. **Device Impersonation**: Rogue device fails signature and registry lookup (`404 Not Found`).
     2. **Replay Attack**: Duplicate sequence packet dropped (`400 Bad Request`).
     3. **Telemetry Tampering**: Bit-flipped ciphertext fails GHASH tag verification (`400 Bad Request`).
     4. **Unauthorized Access**: Clinician attempting admin action blocked (`403 Forbidden`).
     5. **Firmware Tampering**: Altered binary fails ML-DSA signature check (`400 Bad Request`).
     6. **Rate-Limit Attack**: High-frequency packet flood throttled (`429 Too Many Requests`).
     7. **Device Revocation**: Revoked device blocked from session handshake (`403 Forbidden`).
     8. **Audit Modification**: Corrupted ledger record detected by hash chaining (`400 Bad Request`).
   - Every attack displays the 4 required parameters: **Simulated Attack Input**, **Backend Security Mechanism**, **Expected Result**, and **Actual Result**.
4. **Security Center & Firmware Attestation**:
   - In the **Security Center** tab, inspect real-time SIEM alerts sorted by severity (Critical, High, Medium, Low).
   - In the **Firmware Security & Anti-Rollback** card, click **Verify Package** to attest genuine firmware against the Trusted Keystore.
   - Click **Test Rollback Block** to demonstrate anti-rollback defense rejecting a prohibited downgrade (`v1.5.0` < `v2.0.0`).
5. **Tamper-Evident Audit Ledger & External Anchoring**:
   - Open the **Audit Logs** tab. Click **Verify Chain** to cryptographically verify SHA-256 hash-chain continuity.
   - Click **Export Anchor** to view the SHA-256 anchoring digest and review the documented limitation regarding whole-database recomputation.

---

## 📜 Development Status
- **Phase 1**: Monorepo layout, baseline PQC engine, Material 3 Flutter dashboard, simulator CLI, and automated test runners are **operational**.
- **Phase 2**: Firebase Authentication, Firestore RBAC schemas, Firestore Security Rules (`firestore.rules`), route guards, and Riverpod/Provider state management are **operational**.
- For detailed upcoming milestones, see [`docs/roadmap.md`](docs/roadmap.md).
