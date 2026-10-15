/*
Verify that claim line and distinct claim counts reconcile to underlying medical claims
for each plan, service month, and provider type. Zero-claim rows must show zero.
*/
with expected as (
    select
        plan_id,
        service_from_month_start_date as month_start_date,
        billing_provider_type,
        count(*) as expected_claim_line_count,
        count(distinct claim_id) as expected_claim_count
    from {{ ref('fct_medical_claim_lines') }}
    where
        claim_status_code = 'PAID'
        and has_matching_eligibility
        and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
    group by
        plan_id,
        service_from_month_start_date,
        billing_provider_type
),
actual as (
    select
        plan_id,
        month_start_date,
        billing_provider_type,
        claim_line_count as actual_claim_line_count,
        claim_count as actual_claim_count
    from {{ ref('agg_plan_month_provider_type_claim_volume') }}
),
compared as (
    select
        coalesce(e.plan_id, a.plan_id) as plan_id,
        coalesce(e.month_start_date, a.month_start_date) as month_start_date,
        coalesce(e.billing_provider_type, a.billing_provider_type) as billing_provider_type,
        coalesce(e.expected_claim_line_count, 0) as expected_claim_line_count,
        a.actual_claim_line_count,
        coalesce(e.expected_claim_count, 0) as expected_claim_count,
        a.actual_claim_count,
        a.plan_id is null as is_missing_in_agg
    from expected e
    full outer join actual a
        on e.plan_id = a.plan_id
        and e.month_start_date = a.month_start_date
        and e.billing_provider_type = a.billing_provider_type
),
final as (
    select
        case
            when is_missing_in_agg then 'missing_in_agg'
            when actual_claim_line_count is null
                or actual_claim_line_count <> expected_claim_line_count
                then 'claim_line_count_mismatch'
            else 'claim_count_mismatch'
        end as discrepancy_type,
        plan_id,
        month_start_date,
        billing_provider_type,
        expected_claim_line_count,
        actual_claim_line_count,
        expected_claim_count,
        actual_claim_count
    from compared
    where
        is_missing_in_agg
        or actual_claim_line_count is null
        or actual_claim_count is null
        or actual_claim_line_count <> expected_claim_line_count
        or actual_claim_count <> expected_claim_count
)
select * from final
