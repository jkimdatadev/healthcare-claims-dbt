select 
    claim_id,
    claim_line_number,
    place_of_service_code
from {{ ref('stg_medical_claim_lines') }}
where 
    place_of_service_code is not null
    and not regexp_full_match(place_of_service_code, '[0-9]{2}')

    