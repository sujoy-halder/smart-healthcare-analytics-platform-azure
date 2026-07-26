select
    encounter_id,
    patient_id,
    doctor_id,
    hospital_id,
    diagnosis_count,
    lab_result_count,
    last_clinical_event_at
from {{ ref('stg_patient_outcomes') }}
{% if is_incremental() %}
where last_clinical_event_at >= (
    select coalesce(max(last_clinical_event_at), '1900-01-01'::timestamp)
    from {{ this }}
)
{% endif %}
