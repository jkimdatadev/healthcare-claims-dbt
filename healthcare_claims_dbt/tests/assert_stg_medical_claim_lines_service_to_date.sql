select 
    claim_id,
    claim_line_number,
    service_from_date,
    service_to_date
from {{ ref('stg_medical_claim_lines') }}
where service_to_date < service_from_date