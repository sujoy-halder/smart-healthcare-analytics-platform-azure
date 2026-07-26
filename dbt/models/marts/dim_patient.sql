select
    patient_id,
    min(last_clinical_event_at) as first_observed_at,
    max(last_clinical_event_at) as last_observed_at,
    count(distinct encounter_id) as encounter_count
from {{ ref('stg_patient_outcomes') }}
group by patient_id
