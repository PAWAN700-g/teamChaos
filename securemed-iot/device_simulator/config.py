from pydantic_settings import BaseSettings, SettingsConfigDict


class SimulatorSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")

    GATEWAY_API_URL: str = "http://localhost:8000/api/v1"
    DEVICE_ID: str = "MED-DEV-ICU-701A"
    DEVICE_TYPE: str = "ICU_PATIENT_MONITOR"
    TELEMETRY_INTERVAL_SECONDS: float = 2.0

    SIMULATE_ATTACK: bool = False
    ATTACK_TYPE: str = "none"


sim_settings = SimulatorSettings()
