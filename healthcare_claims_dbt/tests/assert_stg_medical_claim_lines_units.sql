select
    claim_id,
    claim_line_number,
    units
from {{ ref('stg_medical_claim_lines') }}
where units <= 0