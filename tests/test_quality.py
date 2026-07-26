from healthcare_platform.contracts import SourceType
from healthcare_platform.quality import quality_score, validate_record


def test_ehr_record_requires_core_fields() -> None:
    result = validate_record(SourceType.EHR, {"patient_id": "p1"})

    assert not result.valid
    assert {issue.field for issue in result.issues} == {
        "diagnosis_code",
        "encounter_id",
        "event_time",
    }


def test_claim_rejects_negative_amount() -> None:
    result = validate_record(
        SourceType.INSURANCE_CLAIM,
        {
            "claim_id": "c1",
            "patient_id": "p1",
            "payer_id": "payer-a",
            "service_date": "2026-07-01",
            "billed_amount": "-10.25",
        },
    )

    assert not result.valid
    assert any(issue.field == "billed_amount" for issue in result.issues)
    assert quality_score(result) < 1.0


def test_appointment_status_is_controlled() -> None:
    result = validate_record(
        SourceType.APPOINTMENT,
        {
            "patient_id": "p1",
            "appointment_id": "a1",
            "scheduled_start_time": "2026-07-01T10:00:00Z",
            "status": "completed",
            "department_id": "cardiology",
        },
    )

    assert result.valid
