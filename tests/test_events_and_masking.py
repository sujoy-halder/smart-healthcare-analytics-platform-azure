import json

import pytest

from healthcare_platform.cloud_events import build_cloud_event, serialize_event
from healthcare_platform.config import RuntimeConfig
from healthcare_platform.contracts import SourceType
from healthcare_platform.masking import deidentify_record, tokenise_identifier


def test_cloud_event_serializes_as_json_bytes() -> None:
    event = build_cloud_event(SourceType.LAB_RESULT, {"patient_id": "p1", "value": 7.2})

    payload = json.loads(serialize_event(event))

    assert payload["specversion"] == "1.0"
    assert payload["type"] == "com.healthcare.lab_result.received"
    assert payload["data"]["value"] == 7.2


def test_deidentify_record_hashes_patient_identifiers() -> None:
    masked = deidentify_record({"patient_id": "patient-123", "mrn": "MRN-1"}, "salt")

    assert masked["patient_id"] == tokenise_identifier("patient-123", "salt")
    assert masked["mrn"] != "MRN-1"


def test_tokenise_identifier_requires_salt() -> None:
    with pytest.raises(ValueError):
        tokenise_identifier("patient-123", "")


def test_prod_runtime_requires_identifier_salt(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ENVIRONMENT", "prod")
    monkeypatch.delenv("IDENTIFIER_SALT", raising=False)
    monkeypatch.delenv("IDENTIFIER_SALT_FILE", raising=False)

    with pytest.raises(RuntimeError):
        RuntimeConfig.from_env("healthcare-api")
