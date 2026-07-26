select
    current_date as snapshot_date,
    (select count(*) from {{ ref('dim_patient') }}) as active_patient_count,
    (select count(*) from {{ ref('fact_encounters') }}) as encounter_count,
    (select sum(claim_count) from {{ ref('fact_claims') }}) as claim_count,
    (select sum(total_billed_amount) from {{ ref('fact_claims') }}) as total_billed_amount
