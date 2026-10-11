/* Verify joins do not duplicate rows; count matched and unmatched rows from each right-side table */
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
    count(*) as total_count, --before left join 42163 --after left join 42163
    sum(case when e.eligibility_segment_id is not null then 1 else 0 end) as matched_elig_count,
    sum(case when e.eligibility_segment_id is null then 1 else 0 end) as unmatched_elig_count,
    sum(case when p.plan_id is not null then 1 else 0 end) as matched_plan_count,
    sum(case when p.plan_id is null then 1 else 0 end) as unmatched_plan_count
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

/* Validate row count, claim-line grain, eligibility matching, and plan population in the enriched model */
select
    count(*) as total_count,
    count(distinct claim_id || '|' || claim_line_number) as distinct_claim_line_count,
    sum(case when has_matching_eligibility then 1 else 0 end) as matched_elig_count,
    sum(case when not has_matching_eligibility then 1 else 0 end) as unmatched_elig_count,
    sum(case when plan_id is not null then 1 else 0 end) as populated_plan_count,
    sum(case when plan_id is null then 1 else 0 end) as null_plan_count
from {{ ref('int_medical_claim_lines_enriched') }}

/* Check duplicate claim-line keys in enriched claims */
select
    claim_id,
    claim_line_number,
    count(*) as row_count
from {{ ref('int_medical_claim_lines_enriched') }}
group by
    claim_id,
    claim_line_number
having count(*) > 1
order by row_count desc

/* Check claims matched before plan effective date */
select
    c.claim_id,
    c.claim_line_number,
    c.member_id,
    c.service_from_date,
    e.plan_id,
    p.effective_date as plan_effective_date
from {{ ref('stg_medical_claim_lines') }} c
join {{ ref('stg_eligibility_segments') }} e
    on c.member_id = e.member_id
    and c.service_from_date between e.effective_date
        and coalesce(e.term_date, cast('2999-12-31' as date))
join {{ ref('stg_plans') }} p
    on e.plan_id = p.plan_id
where c.service_from_date < p.effective_date

/* Check nullability of financial measures in enriched claim lines */
select
    count(*) as total_rows,
    count(*) filter (where billed_amount is null) as billed_amount_nulls,
    count(*) filter (where allowed_amount is null) as allowed_amount_nulls,
    count(*) filter (where paid_amount is null) as paid_amount_nulls,
    count(*) filter (where member_responsibility_amount is null) as member_responsibility_amount_nulls
from main.int_medical_claim_lines_enriched;

/* Check nullability of required claim fields */
select
    count(*) as total_rows,
    count(*) filter (where claim_type_code is null) as claim_type_code_nulls,
    count(*) filter (where claim_status_code is null) as claim_status_code_nulls,
    count(*) filter (where service_from_date is null) as service_from_date_nulls,
    count(*) filter (where service_to_date is null) as service_to_date_nulls,
    count(*) filter (where updated_at is null) as updated_at_nulls
from main.int_medical_claim_lines_enriched;