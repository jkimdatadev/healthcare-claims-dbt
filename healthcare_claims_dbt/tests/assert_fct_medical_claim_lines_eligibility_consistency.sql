/*
Verify that has_matching_eligibility is true when both eligibility_segment_id and plan_id are populated,
and false when both are null.
Flag cases where only one identifier is populated as inconsistent.
*/
select
    claim_id,
    claim_line_number,
    has_matching_eligibility,
    eligibility_segment_id,
    plan_id
from {{ ref('fct_medical_claim_lines') }}
where not (
    (has_matching_eligibility = true
        and eligibility_segment_id is not null
        and plan_id is not null)
    or
    (has_matching_eligibility = false
        and eligibility_segment_id is null
        and plan_id is null)
)
