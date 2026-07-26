select
    payer_id,
    claim_status,
    claim_count,
    total_billed_amount,
    avg_billed_amount,
    loaded_at
from {{ ref('stg_claims_analytics') }}
{% if is_incremental() %}
where loaded_at >= (
    select coalesce(max(loaded_at), '1900-01-01'::timestamp)
    from {{ this }}
)
{% endif %}
