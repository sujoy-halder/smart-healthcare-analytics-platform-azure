select
    h.hospital_id,
    h.encounter_count,
    h.patient_count,
    coalesce(sum(e.lab_result_count), 0) as lab_result_count,
    max(e.last_clinical_event_at) as latest_activity_at
from {{ ref('dim_hospital') }} h
left join {{ ref('fact_encounters') }} e
    on h.hospital_id = e.hospital_id
group by 1, 2, 3
