select
    claim_id,
    claim_line_number,
    revenue_code
from {{ ref('stg_medical_claim_lines') }}
where
    revenue_code is not null
    and not regexp_full_match(revenue_code, '[0-9]{4}')