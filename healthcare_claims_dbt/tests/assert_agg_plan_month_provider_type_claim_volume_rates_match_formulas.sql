/*
Verify that both rates match their formulas for each plan, month, and provider type,
and return null when the enrollment denominator is zero.
*/
with claim_volume as (
    select * from {{ ref('agg_plan_month_provider_type_claim_volume') }}
),
rates as (
    select
        plan_id,
        month_start_date,
        billing_provider_type,
        'claim_lines_per_1000_member_months' as rate_name,
        claim_lines_per_1000_member_months as actual_rate,
        cast(claim_line_count as double) * 1000 / nullif(member_month_count, 0) as expected_rate
    from claim_volume
    union all
    select
        plan_id,
        month_start_date,
        billing_provider_type,
        'claims_per_1000_member_months' as rate_name,
        claims_per_1000_member_months as actual_rate,
        cast(claim_count as double) * 1000 / nullif(member_month_count, 0) as expected_rate
    from claim_volume
),
final as (
    select
        plan_id,
        month_start_date,
        billing_provider_type,
        rate_name,
        expected_rate,
        actual_rate
    from rates
    where
        (expected_rate is null and actual_rate is not null)
        or (expected_rate is not null and actual_rate is null)
        or abs(actual_rate - expected_rate) > 1e-6
)
select * from final
