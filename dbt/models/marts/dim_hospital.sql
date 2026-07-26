select
    hospital_id,
    count(distinct encounter_id) as encounter_count,
    count(distinct patient_id) as patient_count
from {{ ref('stg_patient_outcomes') }}
where hospital_id is not null
group by hospital_id
