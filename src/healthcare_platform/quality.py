from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation
from typing import Any

from healthcare_platform.contracts import (
    REQUIRED_FIELDS,
    VALID_APPOINTMENT_STATUSES,
    VALID_IMAGING_MODALITIES,
    SourceType,
    ValidationIssue,
    ValidationResult,
)


def validate_record(source_type: SourceType, record: dict[str, Any]) -> ValidationResult:
    issues: list[ValidationIssue] = []

    for field in sorted(REQUIRED_FIELDS[source_type]):
        if record.get(field) in (None, ""):
            issues.append(ValidationIssue(field=field, message="Required field is missing"))

    event_field = "scheduled_start_time" if source_type == SourceType.APPOINTMENT else "event_time"
    if event_field in record and record.get(event_field):
        issues.extend(_validate_datetime(event_field, str(record[event_field])))

    if source_type == SourceType.APPOINTMENT:
        status = str(record.get("status", "")).lower()
        if status and status not in VALID_APPOINTMENT_STATUSES:
            issues.append(
                ValidationIssue(
                    field="status",
                    message=f"Invalid appointment status '{status}'",
                )
            )

    if source_type == SourceType.IMAGING_METADATA:
        modality = str(record.get("modality", "")).lower()
        if modality and modality not in VALID_IMAGING_MODALITIES:
            issues.append(
                ValidationIssue(field="modality", message=f"Invalid modality '{modality}'")
            )

    if source_type == SourceType.INSURANCE_CLAIM:
        issues.extend(_validate_non_negative_decimal("billed_amount", record.get("billed_amount")))

    if source_type == SourceType.PATIENT_MONITORING:
        issues.extend(_validate_non_negative_decimal("metric_value", record.get("metric_value")))

    return ValidationResult(
        valid=not any(issue.severity == "error" for issue in issues),
        issues=tuple(issues),
    )


def quality_score(result: ValidationResult) -> float:
    if not result.issues:
        return 1.0
    error_count = sum(1 for issue in result.issues if issue.severity == "error")
    warning_count = len(result.issues) - error_count
    score = 1.0 - (error_count * 0.2) - (warning_count * 0.05)
    return max(score, 0.0)


def _validate_datetime(field: str, value: str) -> list[ValidationIssue]:
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return [ValidationIssue(field=field, message="Expected ISO-8601 timestamp")]

    if parsed.tzinfo is None:
        return [ValidationIssue(field=field, message="Timestamp must include timezone")]

    if parsed.astimezone(UTC) > datetime.now(tz=UTC):
        return [
            ValidationIssue(field=field, message="Timestamp is in the future", severity="warning")
        ]

    return []


def _validate_non_negative_decimal(field: str, value: Any) -> list[ValidationIssue]:
    if value in (None, ""):
        return []
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return [ValidationIssue(field=field, message="Expected numeric value")]
    if parsed < 0:
        return [ValidationIssue(field=field, message="Value must be non-negative")]
    return []
