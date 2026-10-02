select 
    claim_id,
    claim_line_number,
    billing_provider_npi
from {{ ref('stg_medical_claim_lines') }}
where 
    not regexp_full_match(billing_provider_npi, '[0-9]{10}')
    