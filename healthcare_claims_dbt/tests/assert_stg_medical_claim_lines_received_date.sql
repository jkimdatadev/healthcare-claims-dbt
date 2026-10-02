select
    claim_id,
    claim_line_number,
    service_to_date,
    received_date
from {{ ref('stg_medical_claim_lines') }}
where received_date < service_to_date