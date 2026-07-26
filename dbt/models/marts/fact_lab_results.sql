select
    encounter_id,
    patient_id,
    lab_result_count,
    last_clinical_event_at
from {{ ref('stg_patient_outcomes') }}
where lab_result_count > 0
{% if is_incremental() %}
  and last_clinical_event_at >= (
      select coalesce(max(last_clinical_event_at), '1900-01-01'::timestamp)
      from {{ this }}
  )
{% endif %}
