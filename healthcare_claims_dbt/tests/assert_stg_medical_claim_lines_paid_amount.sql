select
    claim_id,
    claim_line_number,
    allowed_amount,
    paid_amount
from {{ ref('stg_medical_claim_lines') }}
where
    paid_amount < 0
    or paid_amount > allowed_amount