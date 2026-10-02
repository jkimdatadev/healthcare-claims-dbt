select
    claim_id,
    claim_line_number,
    allowed_amount,
    member_responsibility_amount
from {{ ref('stg_medical_claim_lines') }}
where
    member_responsibility_amount < 0
    or member_responsibility_amount > allowed_amount