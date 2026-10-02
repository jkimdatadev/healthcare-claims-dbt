select
    claim_id,
    claim_line_number,
    billed_amount
from {{ ref('stg_medical_claim_lines') }}
where billed_amount < 0