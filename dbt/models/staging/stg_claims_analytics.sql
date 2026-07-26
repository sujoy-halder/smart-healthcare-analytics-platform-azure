select
    payer_id,
    claim_status,
    claim_count,
    total_billed_amount,
    avg_billed_amount,
    loaded_at
from {{ source('raw', 'CLAIMS_ANALYTICS') }}
