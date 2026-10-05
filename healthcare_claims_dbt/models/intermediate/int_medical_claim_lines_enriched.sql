with claims as (
    select * from {{ ref('stg_medical_claim_lines') }}
),
eligibility as (
    select * from {{ ref('stg_eligibility_segments') }}
),
plans as (
    select * from {{ ref('stg_plans') }}
)
select 
    c.claim_id,
    c.claim_line_number,
    c.member_id,
    c.claim_type_code,
    c.claim_status_code,
    c.billing_provider_npi,
    c.rendering_provider_npi, 
    c.billing_provider_type,
    c.bill_type_code,
    c.service_from_date,
    c.service_to_date,
    c.received_date,
    c.paid_date,
    c.place_of_service_code,
    c.revenue_code,
    c.procedure_code,
    c.procedure_modifier,
    c.units,
    c.diagnosis_code_1,
    c.diagnosis_code_2,
    c.diagnosis_code_3,
    c.billed_amount,
    c.allowed_amount,
    c.paid_amount,
    c.member_responsibility_amount,
    c.updated_at,
    case when e.eligibility_segment_id is not null then true else false end as has_matching_eligibility,
    e.eligibility_segment_id,
    e.plan_id,
    p.state_code,
    p.product_code,
    p.aid_category_code
from claims c
left join eligibility e
    on c.member_id = e.member_id
    and c.service_from_date >= e.effective_date
    and (
        c.service_from_date <= e.term_date
        or e.term_date is null
    )
left join plans p 
    on e.plan_id = p.plan_id