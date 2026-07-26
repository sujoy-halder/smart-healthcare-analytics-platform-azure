from __future__ import annotations

import json
from uuid import uuid4

from healthcare_platform.contracts import SourceType, utc_now_iso


def build_cloud_event(source_type: SourceType, payload: dict, subject: str | None = None) -> dict:
    event_subject = subject or str(
        payload.get("patient_id") or payload.get("claim_id") or "unknown"
    )
    return {
        "specversion": "1.0",
        "id": str(uuid4()),
        "source": "smart-healthcare-analytics-platform",
        "type": f"com.healthcare.{source_type.value}.received",
        "subject": event_subject,
        "time": utc_now_iso(),
        "datacontenttype": "application/json",
        "data": payload,
    }


def serialize_event(event: dict) -> bytes:
    return json.dumps(event, sort_keys=True, separators=(",", ":")).encode("utf-8")
