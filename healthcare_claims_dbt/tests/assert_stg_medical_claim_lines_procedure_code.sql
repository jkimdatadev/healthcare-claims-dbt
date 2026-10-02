select
    claim_id,
    claim_line_number,
    procedure_code
from {{ ref('stg_medical_claim_lines') }}
where
    procedure_code is not null
    and len(procedure_code) != 5