select
    claim_id,
    claim_line_number,
    procedure_modifier
from {{ ref('stg_medical_claim_lines') }}
where
    procedure_modifier is not null
    and len(procedure_modifier) != 2