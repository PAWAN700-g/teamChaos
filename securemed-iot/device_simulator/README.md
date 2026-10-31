# SecureMed IoT - Medical Device Simulator

The Device Simulator models hospital IoT medical devices (ICU multi-parameter monitors, smart infusion pumps, ambulatory ECG monitors). It generates synthetic patient vitals and communicates with the SecureMed IoT Gateway using post-quantum cryptographic primitives.

> [!CAUTION]
> **HACKATHON PROTOTYPE ONLY**: All telemetry is simulated and synthetic. Never connect this software to real clinical equipment or use it to inform patient care decisions.

---

## Capabilities

- **Synthetic Telemetry Generation**: Generates simulated heart rate, SpO2, blood pressure, respiratory rate, and body temperature within physiological bounds.
- **Post-Quantum Key Encapsulation (ML-KEM-768)**: Executes quantum-safe key exchange with the hospital gateway.
- **Quantum-Safe Digital Signatures (ML-DSA-65)**: Signs telemetry payloads to prove device authenticity and prevent message tampering.
- **Authenticated Encryption (AES-256-GCM)**: Encrypts telemetry using session keys derived via HKDF-SHA-256.
- **Attack Simulation**: Injects simulated MITM tampering, replay packets, and abnormal physiological spikes for security detection benchmarking.

---

## Running the Simulator

```bash
# Ensure dependencies are installed
pip install -r requirements.txt

# Run single-cycle self-test
python simulator.py
```
