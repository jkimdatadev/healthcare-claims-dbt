/* Inspect fct_member_plan_month schema */
describe select * from main.fct_member_plan_month;

/* Inspect fct_member_month schema */
describe select * from main.fct_member_month;

/* Validate medical claim fact row count */
select
    (select count(*) from {{ ref('int_medical_claim_lines_enriched') }}) as source_rows,
    (select count(*) from {{ ref('fct_medical_claim_lines') }}) as fact_rows;

/* Check medical claim fact grain uniqueness */
select
    claim_id,
    claim_line_number,
    count(*) as row_count
from {{ ref('fct_medical_claim_lines') }}
group by
    claim_id,
    claim_line_number
having count(*) > 1;

/* Explore claim status and payment distributions for mart_pmpm */
select
    claim_status_code,
    count(*) as claim_line_count,
    count_if(paid_date is null) as null_paid_date_count,
    count_if(paid_amount > 0) as positive_paid_count,
    count_if(paid_amount = 0) as zero_paid_count,
    count_if(paid_amount < 0) as negative_paid_count,
    sum(paid_amount) as total_paid_amount
from {{ ref('fct_medical_claim_lines') }}
group by claim_status_code
order by claim_status_code;

/* Explore paid claim eligibility matching for mart_pmpm */
select
    has_matching_eligibility,
    count(*) as claim_line_count,
    sum(paid_amount) as total_paid_amount
from {{ ref('fct_medical_claim_lines') }}
where claim_status_code = 'PAID'
group by has_matching_eligibility
order by has_matching_eligibility;

/* Explore paid claim dates relative to the analysis window for mart_pmpm */
select
    cast('{{ var('analysis_through_date') }}' as date) as analysis_through_date,
    min(service_from_date) as earliest_service_date,
    max(service_from_date) as latest_service_date,
    min(paid_date) as earliest_paid_date,
    max(paid_date) as latest_paid_date,
    count_if(
        paid_date > cast('{{ var('analysis_through_date') }}' as date)
    ) as paid_lines_after_analysis_date,
    sum(
        case
            when paid_date > cast('{{ var('analysis_through_date') }}' as date)
            then paid_amount
            else 0
        end
    ) as paid_amount_after_analysis_date
from {{ ref('fct_medical_claim_lines') }}
where claim_status_code = 'PAID';


/* ---------- agg_plan_month_cost ---------- */

/* Enrollment cutoff and subsequent payment-only months */
select
    month_start_date,
    count(*) as plan_rows,
    sum(payment_month_paid_amount) as payment_paid,
    sum(fractional_member_months) as member_months,
    count(payment_month_pmpm_fractional_member) as non_null_pmpm
from {{ ref('agg_plan_month_cost') }}
where month_start_date >= '2026-06-01'
group by month_start_date
order by month_start_date;

/* Service-month and payment-month grand totals should be equal */
select
    sum(service_month_paid_amount) as service_total,
    sum(payment_month_paid_amount) as payment_total,
    sum(service_month_paid_amount) - sum(payment_month_paid_amount) as difference
from {{ ref('agg_plan_month_cost') }};

/* Source total: paid, eligibility-matched claims through the cutoff */
select
    sum(paid_amount) as source_paid_total
from {{ ref('fct_medical_claim_lines') }}
where
    claim_status_code = 'PAID'
    and has_matching_eligibility
    and service_from_date <= cast('{{ var("analysis_through_date") }}' as date);

/* Check column names and data types */
describe select * from {{ ref('agg_plan_month_cost') }};

/* Check for duplicate plan-month combinations; expected: zero rows */
select
    plan_id,
    month_start_date,
    count(*) as row_count
from {{ ref('agg_plan_month_cost') }}
group by
    plan_id,
    month_start_date
having count(*) > 1
order by
    plan_id,
    month_start_date;


/* ---------- agg_plan_month_provider_type_claim_volume ---------- */

/* Examine billing provider types in qualifying paid claims */
select
    billing_provider_type,
    count(*) as claim_line_count,
    count(distinct claim_id) as claim_count
from {{ ref('fct_medical_claim_lines') }}
where
    claim_status_code = 'PAID'
    and has_matching_eligibility
    and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
group by
    billing_provider_type
order by
    billing_provider_type;

/* Find claims associated with multiple billing provider types */
select
    claim_id,
    count(distinct billing_provider_type) as provider_type_count
from {{ ref('fct_medical_claim_lines') }}
where claim_status_code = 'PAID'
    and has_matching_eligibility
    and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
group by claim_id
having count(distinct billing_provider_type) > 1
order by provider_type_count desc, claim_id;

/* Check whether any qualifying claim has lines associated with multiple plans or service months */
select count(*) as claims_spanning_plans_or_months
from (
    select claim_id
    from {{ ref('fct_medical_claim_lines') }}
    where claim_status_code = 'PAID'
        and has_matching_eligibility
        and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
    group by claim_id
    having count(distinct plan_id) > 1
        or count(distinct service_from_month_start_date) > 1
);

/* Check row count against enrolled plan-months × 4 provider types */
select
    (select count(*) from {{ ref('agg_plan_month_provider_type_claim_volume') }}) as agg_rows,
    (select count(*) * 4
     from (
         select distinct plan_id, month_start_date
         from {{ ref('fct_member_plan_month') }}
     )) as expected_rows;

/* Reconcile claim lines against qualifying paid claims */
with source_claims as (
    select count(*) as expected_claim_lines
    from {{ ref('fct_medical_claim_lines') }}
    where claim_status_code = 'PAID'
        and has_matching_eligibility
        and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
),
agg_claims as (
    select
        sum(claim_line_count) as actual_claim_lines,
        sum(case when member_month_count = 0 then 1 else 0 end) as claim_only_rows
    from {{ ref('agg_plan_month_provider_type_claim_volume') }}
)
select
    ac.actual_claim_lines,
    sc.expected_claim_lines,
    ac.claim_only_rows
from agg_claims ac
cross join source_claims sc;

/* Verify zero-claim enrolled rows have both rates equal to zero */
select
    count(*) as zero_claim_enrolled_rows,
    sum(
        case
            when claim_lines_per_1000_member_months = 0
                and claims_per_1000_member_months = 0
            then 1 else 0
        end
    ) as rows_with_zero_rates
from {{ ref('agg_plan_month_provider_type_claim_volume') }}
where claim_line_count = 0
    and member_month_count > 0;