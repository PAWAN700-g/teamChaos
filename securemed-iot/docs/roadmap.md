# SecureMed IoT - Development Roadmap

This roadmap outlines the phased execution strategy for the SecureMed IoT platform hackathon build.

---

## Phase 1: Foundation & Monorepo Initialization 🟢 [COMPLETED]
- [x] Create monorepo folder layout (`frontend/`, `backend/`, `device_simulator/`, `docs/`, `scripts/`).
- [x] Configure backend project configuration (`pyproject.toml`, `requirements.txt`).
- [x] Initialize Flutter Material 3 application with responsive healthcare theme.
- [x] Scaffold Python virtual environment and verified dependency isolation.
- [x] Verify NIST PQC primitives (ML-KEM-768, ML-DSA-65) and symmetric ciphers (AES-256-GCM, HKDF-SHA-256).
- [x] Set up unit test suites (`pytest` for backend, `flutter test` for frontend).
- [x] Write architectural specifications, threat models, and developer guides.

---

## Phase 2: Post-Quantum Cryptographic Handshake Protocol 🟡 [NEXT]
- [ ] Implement formal KEM exchange endpoint (`POST /api/v1/auth/handshake/init` and `POST /api/v1/auth/handshake/complete`).
- [ ] Implement public key registration and certificate/attestation structure for devices.
- [ ] Add session key lifecycle manager with TTL, automatic renegotiation, and revocation.
- [ ] Create benchmark tests measuring PQC handshake latency and packet overhead against classical RSA-2048 and ECDH.

---

## Phase 3: Simulated IoT Medical Fleet & Attack Injector ⚪ [UPCOMING]
- [ ] Expand device simulation profiles:
  - *ICU Multi-parameter Monitor* (ECG waveform, SpO2, NIBP, EtCO2).
  - *Smart Infusion Pump* (Infusion rate, occlusion alarm, bolus delivery status).
  - *Ambulatory Telemetry Transmitter* (Battery level, lead-off alarms, motion telemetry).
- [ ] Build realistic synthetic patient physiological models with baseline drift and noise.
- [ ] Implement Attack Simulation Suite:
  - MITM payload tampering (altering vitals mid-transit).
  - Replay attack injection.
  - Unauthorized device spoofing (missing or invalid ML-DSA-65 signature).
  - High-frequency denial-of-service packet flood.

---

## Phase 4: Backend Anomaly Detection & Attack Mitigation Pipeline ⚪ [UPCOMING]
- [ ] Real-time telemetry ingestion pipeline via FastAPI WebSockets and streaming endpoints.
- [ ] Cryptographic validation pipeline:
  - Nonce reuse detector.
  - Signature verification worker pool.
  - Timestamp / freshness window validator (prevent replay attacks).
- [ ] Medical logic anomaly detection:
  - Physiological plausibility bounds checking (e.g., impossible heart rate jumps).
  - Rate-of-change detectors for vital signs.
- [ ] Security incident alert generator with severity classification (Info, Warning, Critical Breach).

---

## Phase 5: Flutter Security Command Center (Material 3) ⚪ [UPCOMING]
- [ ] **Fleet Overview Screen**: Interactive cards showing real-time status of all hospital ward devices.
- [ ] **Live Telemetry & Waveform Visualizer**: Real-time rendering of synthetic vitals and simulated ECG traces.
- [ ] **Cryptographic Security Inspector**: Interactive visualizer showing:
  - Active ML-KEM-768 session keys and age.
  - ML-DSA-65 attestation status.
  - Ciphertext vs Plaintext inspection for educational demonstration.
- [ ] **Threat Defense & Attack Console**: Real-time attack feed showing blocked attacks with alert badges and incident logs.

---

## Phase 6: Cloud Identity & Persistence (Firebase + Firestore) ⚪ [UPCOMING]
- [ ] Firebase Authentication integration:
  - Clinician Role (Read-only patient telemetry).
  - Biomedical Engineer Role (Device enrollment, firmware attestation).
  - SecOps Analyst Role (Attack response, key revocation).
- [ ] Cloud Firestore synchronization for persistent audit trail and incident reporting.
- [ ] Firestore Security Rules protecting patient records and device credentials.

---

## Phase 7: Verification, Demo Hardening & Presentation Package ⚪ [FINAL]
- [ ] End-to-end integration test automating: Device Boot -> PQC Handshake -> Telemetry Stream -> Attack Injection -> Attack Detection -> Dashboard Alert.
- [ ] Performance and security benchmarking documentation (CPU impact, bandwidth delta, PQC resistance).
- [ ] Pitch deck, demo video script, and hackathon presentation assets.
