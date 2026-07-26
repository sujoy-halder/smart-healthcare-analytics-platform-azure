select
    p.patient_id,
    p.encounter_count,
    p.first_observed_at,
    p.last_observed_at,
    coalesce(sum(e.lab_result_count), 0) as total_lab_results,
    coalesce(sum(e.diagnosis_count), 0) as total_diagnoses
from {{ ref('dim_patient') }} p
left join {{ ref('fact_encounters') }} e
    on p.patient_id = e.patient_id
group by 1, 2, 3, 4
