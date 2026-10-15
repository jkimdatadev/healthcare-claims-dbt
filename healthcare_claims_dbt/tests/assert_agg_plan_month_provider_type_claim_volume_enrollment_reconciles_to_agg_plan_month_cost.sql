/*
Verify that both enrollment denominators on every provider-type row match agg_plan_month_cost
for the same plan and month. This also confirms the denominators are identical across provider types.
*/
with cost_enrollment as (
    select
        plan_id,
        month_start_date,
        member_month_count as expected_member_month_count,
        fractional_member_months as expected_fractional_member_months
    from {{ ref('agg_plan_month_cost') }}
),
claim_volume_enrollment as (
    select
        plan_id,
        month_start_date,
        billing_provider_type,
        member_month_count as actual_member_month_count,
        fractional_member_months as actual_fractional_member_months
    from {{ ref('agg_plan_month_provider_type_claim_volume') }}
),
compared as (
    select
        cve.plan_id,
        cve.month_start_date,
        cve.billing_provider_type,
        coalesce(ce.expected_member_month_count, 0) as expected_member_month_count,
        cve.actual_member_month_count,
        coalesce(ce.expected_fractional_member_months, 0) as expected_fractional_member_months,
        cve.actual_fractional_member_months
    from claim_volume_enrollment cve
    left join cost_enrollment ce
        on cve.plan_id = ce.plan_id
        and cve.month_start_date = ce.month_start_date
),
final as (
    select
        case
            when actual_member_month_count is null
                or actual_member_month_count <> expected_member_month_count
                then 'member_month_count_mismatch'
            else 'fractional_member_months_mismatch'
        end as discrepancy_type,
        plan_id,
        month_start_date,
        billing_provider_type,
        expected_member_month_count,
        actual_member_month_count,
        expected_fractional_member_months,
        actual_fractional_member_months
    from compared
    where
        actual_member_month_count is null
        or actual_fractional_member_months is null
        or actual_member_month_count <> expected_member_month_count
        or abs(actual_fractional_member_months - expected_fractional_member_months) > 1e-9
)
select * from final
