/*Verify joins do not duplicate rows; count matched and unmatched rows from each right-side table */
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

/*Validate row count, claim-line grain, eligibility matching, and plan population in the enriched model */
select
    count(*) as total_count,
    count(distinct claim_id || '|' || claim_line_number) as distinct_claim_line_count,
    sum(case when has_matching_eligibility then 1 else 0 end) as matched_elig_count,
    sum(case when not has_matching_eligibility then 1 else 0 end) as unmatched_elig_count,
    sum(case when plan_id is not null then 1 else 0 end) as populated_plan_count,
    sum(case when plan_id is null then 1 else 0 end) as null_plan_count
from {{ ref('int_medical_claim_lines_enriched') }}
