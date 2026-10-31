# SecureMed IoT - Medical Device Fleet Simulator

The **SecureMed IoT Device Simulator** is a cybersecurity test suite and multi-device simulator modeling connected hospital patient-monitoring equipment:
1. **12-Lead ECG Monitor** (`MED-DEV-ECG-101`)
2. **Wearable Heart-Rate Monitor** (`MED-DEV-HR-202`)
3. **Pulse Oximeter / SpO2 Monitor** (`MED-DEV-SPO2-303`)

It communicates with the FastAPI Gateway using real post-quantum cryptography (NIST FIPS 203 ML-KEM-768 and NIST FIPS 204 ML-DSA-65) and authenticated encryption (AES-256-GCM + HKDF-SHA-256).

> [!CAUTION]
> **HACKATHON CYBERSECURITY PROTOTYPE ONLY**: All generated patient telemetry and vital signs are strictly synthetic. Never connect this simulator to live hospital medical devices or use it to inform clinical decisions.

---

## Simulated Medical Device Fleet

| Device ID | Device Type | Synthetic Telemetry Readings | Operational Status |
| :--- | :--- | :--- | :--- |
| `MED-DEV-ECG-101` | **12-Lead ECG Monitor** | Heart rate (bpm), R-R interval (ms), QRS duration (ms), ST deviation (mV), 20-sample Lead II discrete ECG waveform, Sinus rhythm classification | Normal / Warning / Calibrating |
| `MED-DEV-HR-202` | **Heart-Rate Monitor** | Heart rate (bpm), HRV RMSSD (ms), Pulse quality confidence (%), Activity context | Normal / Battery Low |
| `MED-DEV-SPO2-303` | **SpO2 Pulse Oximeter** | Oxygen saturation ($\text{SpO}_2$ %), Pulse rate (bpm), Perfusion Index ($\text{PI} \%$), Pleth amplitude, Finger probe status | Normal / Probe Disconnected |

Each device maintains:
- **Unique Device ID & Type**
- **Cryptographic Identity**: NIST FIPS 204 ML-DSA-65 private/public keypair ($1{,}952$-byte public key).
- **Connection State Machine**: `DISCONNECTED` $\rightarrow$ `REGISTERED` $\rightarrow$ `AUTHENTICATED` $\rightarrow$ `TRANSMITTING` $\rightarrow$ `REVOKED`.
- **Session State**: Session ID (`SES-...`), $256$-bit AES symmetric key derived via HKDF-SHA-256, expiration TTL, and transcript hash binding.
- **Strict Monotonic Sequence Counter**: Increments with every transmission to detect replay attacks.
- **Last-Seen Timestamp**: Recorded from Gateway verification responses.

---

## Cryptographic Workflow

```
Simulated Device                                          FastAPI Gateway
       │                                                         │
       │─────── 1. Register Public Key (ML-DSA-65) ──────────────>│ (Never sends private key)
       │<────── 201 Created / Device ID Bound ───────────────────│
       │                                                         │
       │─────── 2. POST /crypto/handshake/init ─────────────────>│
       │<────── Ephemeral ML-KEM-768 PubKey + Random Challenge ──│
       │                                                         │
       │  [Encapsulate ML-KEM-768 Secret]                        │
       │  [Sign Challenge with ML-DSA-65]                        │
       │  [Derive Session Keys via HKDF-SHA-256]                 │
       │                                                         │
       │─────── 3. POST /crypto/handshake/complete ─────────────>│
       │         (Ciphertext + Signed Challenge + Salt)          │  [Verify ML-DSA-65 Sig]
       │                                                         │  [Decapsulate ML-KEM]
       │<────── 200 OK (Session ID: SES-..., TTL: 3600s) ────────│  [Derive Matching Keys]
       │                                                         │
       │── 4. Ingest Telemetry Envelope ────────────────────────>│
       │      - AES-256-GCM Ciphertext                           │  [Validate Sequence & Nonce]
       │      - AAD (DeviceID:SessionID:Seq:Timestamp)           │  [Check Clock Skew ±60s]
       │      - ML-DSA-65 Payload Signature                      │  [Decrypt & Verify GCM Tag]
       │<────── 200 OK (Verified + Tamper-evident Audit) ────────│  [Verify ML-DSA-65 Signature]
```

---

## Command-Line Interface (CLI)

The simulator includes a flexible CLI to start one, multiple, or all simulated medical devices with configurable intervals and attack injection modes.

### Prerequisites & Setup

Ensure the Python virtual environment is activated and dependencies are installed:

```bash
# In securemed-iot/backend:
source .venv/bin/activate  # Or on Windows: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
pip install -r ../device_simulator/requirements.txt
```

### CLI Options

```text
usage: simulator.py [-h] [--devices DEVICES] [--gateway GATEWAY] [--interval INTERVAL]
                    [--count COUNT] [--attack {none,anomaly,replay,tamper_ciphertext,tamper_signature,stale_timestamp}]
                    [--verify]

options:
  --devices DEVICES    Devices to simulate: 'all', 'ecg', 'hr', 'spo2' (default: 'all')
  --gateway GATEWAY    FastAPI Gateway URL (default: http://localhost:8000/api/v1)
  --interval INTERVAL  Transmission interval between packets in seconds (default: 2.0)
  --count COUNT        Number of packets per device (0 for continuous loop, default: 5)
  --attack ATTACK      Cybersecurity test attack mode (default: 'none')
  --verify             Execute automated end-to-end verification suite against Gateway and exit
```

---

## Usage Examples

### 1. Run the Entire Fleet (Default 5 Packets)
Simulates all three devices (`ECG`, `Heart Rate`, `SpO2`) transmitting concurrently:
```bash
python simulator.py --devices all
```

### 2. Stream a Single Device Continuously
Stream the 12-Lead ECG monitor with a $3.0$-second interval continuously:
```bash
python simulator.py --devices ecg --interval 3.0 --count 0
```

### 3. Simulate Clinical Physiological Anomaly
Injects extreme synthetic vital spikes (ventricular tachycardia / hypoxia) to verify that SIEM anomaly detection flags the reading without dropping encryption:
```bash
python simulator.py --devices spo2 --attack anomaly --count 3
```

### 4. Cybersecurity Defense Testing
Simulate active attacks to verify rejection by the hospital gateway:

- **Replay Attack**:
  ```bash
  python simulator.py --devices hr --attack replay --count 2
  ```
  *Result*: Gateway detects duplicate sequence number and rejects with HTTP `400 Bad Request` (`REPLAY_ATTACK_DETECTED`).

- **MITM Ciphertext Tampering**:
  ```bash
  python simulator.py --devices ecg --attack tamper_ciphertext --count 2
  ```
  *Result*: Gateway detects AES-256-GCM authentication tag mismatch and rejects with HTTP `400 Bad Request`.

- **Digital Signature Forgery**:
  ```bash
  python simulator.py --devices spo2 --attack tamper_signature --count 2
  ```
  *Result*: Gateway ML-DSA-65 verification fails; packet rejected with HTTP `401 Unauthorized`.

- **Stale Timestamp Drift**:
  ```bash
  python simulator.py --devices ecg --attack stale_timestamp --count 2
  ```
  *Result*: Timestamp outside the $\pm 60$-second window rejected with HTTP `400 Bad Request`.

---

## Automated Verification Suite

Run all verification checks across device registration, PQC handshakes, encryption, and attack rejections:

```bash
# Via simulator CLI:
python simulator.py --verify

# Or via pytest:
pytest test_simulator.py -v
```

All 12 pytest verification tests run in $< 1$ second and validate zero secret leakage and 100% cryptographic compliance.
