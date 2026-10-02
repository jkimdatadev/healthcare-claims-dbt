select
    claim_id,
    claim_line_number,
    claim_status_code,
    paid_date
from {{ ref('stg_medical_claim_lines') }}
where 
    (claim_status_code = 'PAID' and paid_date is null)
    or (paid_date is not null and paid_date < received_date)