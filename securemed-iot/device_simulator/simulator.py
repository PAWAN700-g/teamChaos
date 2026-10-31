"""SecureMed IoT - Multi-Device Medical Simulator & Orchestrator.

Orchestrates simulated Post-Quantum medical IoT devices:
1. ECG Monitor (MED-DEV-ECG-101)
2. Heart-Rate Monitor (MED-DEV-HR-202)
3. SpO2 Monitor (MED-DEV-SPO2-303)

DISCLAIMER:
Hackathon cybersecurity prototype only.
Simulated medical devices & synthetic patient data only.
Never connect to actual medical equipment or perform clinical decisions.
All telemetry readings are explicitly synthetic.
"""

import sys
import os
import time
import argparse
import logging
import threading
from typing import List, Dict, Any, Optional

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

from models import DeviceType, DeviceStatus, ConnectionState
from device import MedicalDevice
from config import sim_settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("SimulatorCLI")


DEVICE_PROFILES = {
    "ecg": {
        "device_id": "MED-DEV-ECG-101",
        "device_type": DeviceType.ECG_MONITOR,
        "name": "Post-Quantum 12-Lead ECG Monitor",
        "battery": 98,
    },
    "hr": {
        "device_id": "MED-DEV-HR-202",
        "device_type": DeviceType.HEART_RATE_MONITOR,
        "name": "Post-Quantum Wearable Heart-Rate Monitor",
        "battery": 92,
    },
    "spo2": {
        "device_id": "MED-DEV-SPO2-303",
        "device_type": DeviceType.SPO2_MONITOR,
        "name": "Post-Quantum Pulse Oximeter / SpO2 Monitor",
        "battery": 87,
    },
}


class MedicalDeviceFleet:
    """Manages lifecycle and concurrent telemetry streaming for multiple devices."""

    def __init__(self, gateway_url: str):
        self.gateway_url = gateway_url.rstrip("/")
        self.devices: Dict[str, MedicalDevice] = {}

    def add_device(self, key: str, custom_id: Optional[str] = None) -> MedicalDevice:
        """Instantiates and registers a simulated device profile."""
        profile = DEVICE_PROFILES.get(key.lower())
        if not profile:
            raise ValueError(f"Unknown device profile '{key}'. Choices: {list(DEVICE_PROFILES.keys())}")

        dev_id = custom_id or profile["device_id"]
        device = MedicalDevice(
            device_id=dev_id,
            device_type=profile["device_type"],
            name=profile["name"],
            gateway_url=self.gateway_url,
            initial_battery=profile["battery"],
        )
        self.devices[dev_id] = device
        return device

    def bootstrap_device(self, device: MedicalDevice) -> bool:
        """Performs initial registration and PQC handshake."""
        logger.info(f"=== Bootstrapping {device.name} ({device.device_id}) ===")
        if not device.register():
            logger.error(f"[{device.device_id}] Gateway registration failed.")
            return False

        if not device.establish_session():
            logger.error(f"[{device.device_id}] PQC handshake failed.")
            return False

        return True

    def run_device_loop(
        self,
        device: MedicalDevice,
        count: int = 5,
        interval: float = 2.0,
        attack_type: str = "none",
        stop_event: Optional[threading.Event] = None,
    ):
        """Streams telemetry packets for a single device."""
        if not self.bootstrap_device(device):
            logger.error(f"[{device.device_id}] Bootstrapping failed. Stopping transmission thread.")
            return

        packets_sent = 0
        is_attack = attack_type != "none"

        logger.info(
            f"[{device.device_id}] Starting telemetry streaming (Interval: {interval}s | "
            f"Packets: {'Continuous' if count == 0 else count} | Attack: {attack_type})..."
        )

        while True:
            if stop_event and stop_event.is_set():
                break

            packets_sent += 1
            print(f"\n--- [{device.device_id}] Transmitting Packet #{packets_sent} ---")
            success, result = device.emit_telemetry(
                is_attack=is_attack,
                attack_type=attack_type,
            )

            # Check if device was revoked or encountered fatal error
            if device.connection_state == ConnectionState.REVOKED:
                logger.error(f"[{device.device_id}] Device has been revoked. Halting streaming thread.")
                break

            if count > 0 and packets_sent >= count:
                logger.info(f"[{device.device_id}] Completed configured packet count ({count}). Exiting thread.")
                break

            time.sleep(interval)


def print_banner():
    banner = """
================================================================================
   SecureMed IoT - Post-Quantum Medical Device Fleet Simulator
   Algorithms: NIST FIPS 203 ML-KEM-768 | NIST FIPS 204 ML-DSA-65 | AES-256-GCM
   DISCLAIMER: HACKATHON PROTOTYPE ONLY. SYNTHETIC MEDICAL DATA. NEVER FOR CLINICAL USE.
================================================================================
"""
    print(banner)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="SecureMed IoT - Medical Device Fleet Simulator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all 3 devices (ECG, Heart Rate, SpO2) with default 5 packets each:
  python simulator.py --devices all

  # Run only the ECG monitor continuously with 3-second intervals:
  python simulator.py --devices ecg --interval 3.0 --count 0

  # Simulate a physiological anomaly attack on the SpO2 monitor:
  python simulator.py --devices spo2 --attack anomaly --count 3

  # Run the end-to-end cryptographic and cybersecurity verification suite:
  python simulator.py --verify
        """,
    )
    parser.add_argument(
        "--devices",
        type=str,
        default="all",
        help="Devices to simulate: 'all', 'ecg', 'hr', 'spo2', or comma-separated combination (default: 'all')",
    )
    parser.add_argument(
        "--gateway",
        type=str,
        default=sim_settings.GATEWAY_API_URL,
        help=f"FastAPI Gateway URL (default: {sim_settings.GATEWAY_API_URL})",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=2.0,
        help="Transmission interval between packets in seconds (default: 2.0)",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=5,
        help="Number of packets to transmit per device (0 for continuous loop, default: 5)",
    )
    parser.add_argument(
        "--attack",
        type=str,
        default="none",
        choices=["none", "anomaly", "replay", "tamper_ciphertext", "tamper_signature", "stale_timestamp"],
        help="Cybersecurity test attack mode (default: 'none')",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Execute automated end-to-end verification suite against Gateway and exit",
    )
    return parser.parse_args()


def main():
    print_banner()
    args = parse_arguments()

    if args.verify:
        from test_simulator import run_verification_suite
        success = run_verification_suite(gateway_url=args.gateway)
        sys.exit(0 if success else 1)

    fleet = MedicalDeviceFleet(gateway_url=args.gateway)

    # Determine which devices to start
    target_keys = []
    if args.devices.strip().lower() == "all":
        target_keys = ["ecg", "hr", "spo2"]
    else:
        for k in args.devices.split(","):
            k_clean = k.strip().lower()
            if k_clean in DEVICE_PROFILES:
                target_keys.append(k_clean)
            else:
                logger.warning(f"Unknown device identifier '{k}'. Skipping.")

    if not target_keys:
        logger.error("No valid devices selected. Choose from: 'all', 'ecg', 'hr', 'spo2'.")
        sys.exit(1)

    print(f"Selected Simulated Devices: {[DEVICE_PROFILES[k]['name'] for k in target_keys]}")
    print(f"Connecting to Gateway at: {args.gateway}")
    print(f"Interval: {args.interval}s | Packets per device: {'Continuous' if args.count == 0 else args.count}")
    print(f"Attack Simulation Mode: {args.attack}\n")

    threads: List[threading.Thread] = []
    stop_event = threading.Event()

    try:
        for key in target_keys:
            device = fleet.add_device(key)
            t = threading.Thread(
                target=fleet.run_device_loop,
                kwargs={
                    "device": device,
                    "count": args.count,
                    "interval": args.interval,
                    "attack_type": args.attack,
                    "stop_event": stop_event,
                },
                daemon=True,
            )
            threads.append(t)
            t.start()
            # Stagger startup slightly to avoid socket clash
            time.sleep(0.5)

        for t in threads:
            t.join()

        print("\n" + "=" * 80)
        print("All device simulation sessions completed successfully.")
        print("Device Fleet State Summary:")
        for dev_id, dev in fleet.devices.items():
            s = dev.get_state_summary()
            print(f" - [{s['device_id']}] {s['name']}: State={s['connection_state']} | Status={s['device_status']} | Seq={s['sequence_counter']} | Last Seen={s['last_seen_timestamp']}")
        print("=" * 80)

    except KeyboardInterrupt:
        logger.info("\nCaught keyboard interrupt. Signaling all simulator threads to stop...")
        stop_event.set()
        for t in threads:
            t.join(timeout=1.0)
        print("Simulator stopped.")


if __name__ == "__main__":
    main()
