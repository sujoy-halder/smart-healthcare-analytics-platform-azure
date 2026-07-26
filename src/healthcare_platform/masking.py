from __future__ import annotations

import hashlib
from typing import Any

from healthcare_platform.contracts import PATIENT_IDENTIFIER_FIELDS


def tokenise_identifier(value: str, salt: str) -> str:
    if not salt:
        raise ValueError("salt must be configured")
    digest = hashlib.sha256(f"{salt}:{value}".encode()).hexdigest()
    return digest[:32]


def deidentify_record(record: dict[str, Any], salt: str) -> dict[str, Any]:
    masked = dict(record)
    for field in PATIENT_IDENTIFIER_FIELDS:
        if field in masked and masked[field] not in (None, ""):
            masked[field] = tokenise_identifier(str(masked[field]), salt)
    return masked
