"""Synthetic Medical Telemetry Models.

IMPORTANT: Strictly synthetic data for hackathon cybersecurity testing.
Never connect to actual medical equipment or perform clinical decisions.
"""

from pydantic import BaseModel, Field
import random
from datetime import datetime, timezone


class SyntheticPatientVitals(BaseModel):
    patient_synthetic_id: str = "SYN-PT-808"
    timestamp: str
    heart_rate_bpm: int
    spo2_percentage: int
    blood_pressure_systolic: int
    blood_pressure_diastolic: int
    respiratory_rate_rpm: int
    temperature_celsius: float

    @classmethod
    def generate_random_normal(cls, patient_id: str = "SYN-PT-808") -> "SyntheticPatientVitals":
        """Generate normal synthetic patient telemetry."""
        return cls(
            patient_synthetic_id=patient_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
            heart_rate_bpm=random.randint(65, 88),
            spo2_percentage=random.randint(96, 100),
            blood_pressure_systolic=random.randint(115, 128),
            blood_pressure_diastolic=random.randint(75, 84),
            respiratory_rate_rpm=random.randint(12, 18),
            temperature_celsius=round(random.uniform(36.5, 37.2), 1),
        )

    @classmethod
    def generate_tampered_attack_sample(cls, patient_id: str = "SYN-PT-808") -> "SyntheticPatientVitals":
        """Generate anomalous / attacked synthetic telemetry for cybersecurity testing."""
        return cls(
            patient_synthetic_id=patient_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
            heart_rate_bpm=random.randint(180, 220),  # Extreme ventricular tachycardia
            spo2_percentage=random.randint(60, 75),   # Severe hypoxia injection
            blood_pressure_systolic=random.randint(210, 240),
            blood_pressure_diastolic=random.randint(120, 140),
            respiratory_rate_rpm=random.randint(35, 45),
            temperature_celsius=round(random.uniform(41.0, 42.5), 1),
        )
