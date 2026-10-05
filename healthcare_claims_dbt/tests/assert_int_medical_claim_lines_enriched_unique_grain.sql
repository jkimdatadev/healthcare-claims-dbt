select
    claim_id,
    claim_line_number,
    count(*) as row_count
from {{ ref('int_medical_claim_lines_enriched') }}
group by
    claim_id,
    claim_line_number
having count(*) > 1