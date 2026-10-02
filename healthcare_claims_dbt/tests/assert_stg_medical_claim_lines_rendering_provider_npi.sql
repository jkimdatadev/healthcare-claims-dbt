select 
    claim_id,
    claim_line_number,
    rendering_provider_npi
from {{ ref('stg_medical_claim_lines') }}
where 
    rendering_provider_npi is not null
    and not regexp_full_match(rendering_provider_npi, '[0-9]{10}')
