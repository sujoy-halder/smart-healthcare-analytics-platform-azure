select
    payer_id,
    claim_status,
    sum(claim_count) as claim_count,
    sum(total_billed_amount) as total_billed_amount,
    avg(avg_billed_amount) as avg_billed_amount
from {{ ref('fact_claims') }}
group by 1, 2
