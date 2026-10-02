select 
    claim_id,
    claim_line_number,
    count(*) as row_count
from {{ ref('stg_medical_claim_lines') }}
group by 
    claim_id,
    claim_line_number
having count(*) > 1