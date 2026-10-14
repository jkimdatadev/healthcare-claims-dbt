/*
Verify that all four PMPM ratios match their formulas for each plan and month.
Each ratio equals paid amount / denominator when the denominator is positive,
and returns null when the denominator is zero.
*/
with agg as (
    select * from {{ ref('agg_plan_month_cost') }}
),
ratios as (
    select
        plan_id,
        month_start_date,
        'service_month_pmpm_member_count' as ratio_name,
        service_month_pmpm_member_count as actual_ratio,
        service_month_paid_amount / nullif(member_month_count, 0) as expected_ratio
    from agg
    union all
    select
        plan_id,
        month_start_date,
        'service_month_pmpm_fractional_member' as ratio_name,
        service_month_pmpm_fractional_member as actual_ratio,
        service_month_paid_amount / nullif(fractional_member_months, 0) as expected_ratio
    from agg
    union all
    select
        plan_id,
        month_start_date,
        'payment_month_pmpm_member_count' as ratio_name,
        payment_month_pmpm_member_count as actual_ratio,
        payment_month_paid_amount / nullif(member_month_count, 0) as expected_ratio
    from agg
    union all
    select
        plan_id,
        month_start_date,
        'payment_month_pmpm_fractional_member' as ratio_name,
        payment_month_pmpm_fractional_member as actual_ratio,
        payment_month_paid_amount / nullif(fractional_member_months, 0) as expected_ratio
    from agg
),
final as (
    select
        plan_id,
        month_start_date,
        ratio_name,
        expected_ratio,
        actual_ratio
    from ratios
    where
        (expected_ratio is null and actual_ratio is not null)
        or (expected_ratio is not null and actual_ratio is null)
        or abs(actual_ratio - expected_ratio) > 1e-6
)
select * from final
