select
    claim_id,
    claim_line_number,
    billed_amount,
    allowed_amount
from {{ ref('stg_medical_claim_lines') }}
where
    allowed_amount < 0
    or allowed_amount > billed_amount