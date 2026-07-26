select
    patient_id,
    encounter_id,
    doctor_id,
    hospital_id,
    diagnosis_count,
    lab_result_count,
    last_clinical_event_at,
    loaded_at
from {{ source('raw', 'PATIENT_OUTCOMES') }}
