from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from enum import StrEnum
from typing import Any


class SourceType(StrEnum):
    EHR = "ehr"
    LAB_RESULT = "lab_result"
    PHARMACY_TRANSACTION = "pharmacy_transaction"
    APPOINTMENT = "appointment"
    IMAGING_METADATA = "imaging_metadata"
    PATIENT_MONITORING = "patient_monitoring"
    INSURANCE_CLAIM = "insurance_claim"


REQUIRED_FIELDS: dict[SourceType, set[str]] = {
    SourceType.EHR: {"patient_id", "encounter_id", "event_time", "diagnosis_code"},
    SourceType.LAB_RESULT: {"patient_id", "encounter_id", "event_time", "test_code", "value"},
    SourceType.PHARMACY_TRANSACTION: {
        "patient_id",
        "prescription_id",
        "event_time",
        "ndc_code",
        "dispensed_quantity",
    },
    SourceType.APPOINTMENT: {
        "patient_id",
        "appointment_id",
        "scheduled_start_time",
        "status",
        "department_id",
    },
    SourceType.IMAGING_METADATA: {
        "patient_id",
        "study_instance_uid",
        "event_time",
        "modality",
        "body_part",
    },
    SourceType.PATIENT_MONITORING: {
        "patient_id",
        "device_id",
        "event_time",
        "metric_name",
        "metric_value",
    },
    SourceType.INSURANCE_CLAIM: {
        "claim_id",
        "patient_id",
        "payer_id",
        "service_date",
        "billed_amount",
    },
}


VALID_APPOINTMENT_STATUSES = {"scheduled", "completed", "cancelled", "no_show"}
VALID_IMAGING_MODALITIES = {"ct", "mri", "xray", "ultrasound", "pet", "mammography"}
PATIENT_IDENTIFIER_FIELDS = {"patient_id", "mrn", "member_id"}


@dataclass(frozen=True)
class ValidationIssue:
    field: str
    message: str
    severity: str = "error"


@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    issues: tuple[ValidationIssue, ...]

    def as_dict(self) -> dict[str, Any]:
        return {
            "valid": self.valid,
            "issues": [
                {"field": issue.field, "message": issue.message, "severity": issue.severity}
                for issue in self.issues
            ],
        }


def parse_source_type(value: str) -> SourceType:
    try:
        return SourceType(value)
    except ValueError as exc:
        allowed = ", ".join(item.value for item in SourceType)
        raise ValueError(f"Unsupported source_type '{value}'. Expected one of: {allowed}") from exc


def utc_now_iso() -> str:
    return datetime.now(tz=UTC).isoformat(timespec="seconds").replace("+00:00", "Z")
