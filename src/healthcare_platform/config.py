from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

DEFAULT_LOCAL_IDENTIFIER_SALT = "local-dev-salt-change-me"


@dataclass(frozen=True)
class RuntimeConfig:
    environment: str
    service_name: str
    local_outbox_path: Path
    identifier_salt: str

    @classmethod
    def from_env(cls, service_name: str) -> RuntimeConfig:
        environment = os.getenv("ENVIRONMENT", "dev")
        identifier_salt = _secret_value("IDENTIFIER_SALT", DEFAULT_LOCAL_IDENTIFIER_SALT)
        if environment.lower() in {"prod", "production"} and (
            not identifier_salt or identifier_salt == DEFAULT_LOCAL_IDENTIFIER_SALT
        ):
            raise RuntimeError("IDENTIFIER_SALT or IDENTIFIER_SALT_FILE must be configured in prod")

        return cls(
            environment=environment,
            service_name=os.getenv("SERVICE_NAME", service_name),
            local_outbox_path=Path(os.getenv("LOCAL_OUTBOX_PATH", "local_outbox")),
            identifier_salt=identifier_salt,
        )


def _secret_value(name: str, default: str = "") -> str:
    file_path = os.getenv(f"{name}_FILE")
    if file_path:
        return Path(file_path).read_text(encoding="utf-8").strip()
    return os.getenv(name, default)
