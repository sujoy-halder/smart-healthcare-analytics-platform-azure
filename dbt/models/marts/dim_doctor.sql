select
    doctor_id,
    count(distinct encounter_id) as encounter_count,
    count(distinct patient_id) as patient_count
from {{ ref('stg_patient_outcomes') }}
where doctor_id is not null
group by doctor_id
