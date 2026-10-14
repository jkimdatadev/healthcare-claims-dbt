with paid_claim_lines as (
    -- Select paid claims with matching eligibility for services on or before the cutoff date
    select
        plan_id,
        service_from_month_start_date,
        cast(date_trunc('month', paid_date) as date) as payment_month_start_date,
        paid_amount
    from {{ ref('fct_medical_claim_lines') }}
    where
        claim_status_code = 'PAID'
        and has_matching_eligibility
        and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
),
service_month_paid as (
    -- Group paid claims by the month when the service was provided
    select
        plan_id,
        service_from_month_start_date as month_start_date,
        sum(paid_amount) as service_month_paid_amount
    from paid_claim_lines
    group by
        plan_id,
        service_from_month_start_date
),
payment_month_paid as (
    -- Group paid claims by the month when the payment was made
    select
        plan_id,
        payment_month_start_date as month_start_date,
        sum(paid_amount) as payment_month_paid_amount
    from paid_claim_lines
    group by
        plan_id,
        payment_month_start_date
),
plan_month_enrollment as (
    -- Count member-month combinations and sum fractional member months for each plan and month
    select
        plan_id,
        month_start_date,
        count(*) as member_month_count,
        sum(member_month_exposure) as fractional_member_months
    from {{ ref('fct_member_plan_month') }}
    group by
        plan_id,
        month_start_date
),
plan_month_keys as (
    -- Combine distinct plan and month pairs from the three CTEs above
    select plan_id, month_start_date from service_month_paid
    union
    select plan_id, month_start_date from payment_month_paid
    union
    select plan_id, month_start_date from plan_month_enrollment
),
plan_month_measures as (
    -- Join paid amounts and enrollment measures to each plan and month pair
    select
        pmk.plan_id,
        pmk.month_start_date,
        coalesce(smp.service_month_paid_amount, 0) as service_month_paid_amount,
        coalesce(pmp.payment_month_paid_amount, 0) as payment_month_paid_amount,
        coalesce(pme.member_month_count, 0) as member_month_count,
        coalesce(pme.fractional_member_months, 0) as fractional_member_months
    from plan_month_keys pmk
    left join service_month_paid smp
        on pmk.plan_id = smp.plan_id
        and pmk.month_start_date = smp.month_start_date
    left join payment_month_paid pmp
        on pmk.plan_id = pmp.plan_id
        and pmk.month_start_date = pmp.month_start_date
    left join plan_month_enrollment pme
        on pmk.plan_id = pme.plan_id
        and pmk.month_start_date = pme.month_start_date
),
plans as (
    -- Select plan natural key columns and attributes for reporting
    select
        plan_id,
        plan_brand_code,
        aid_category_code,
        plan_benefit_package_code,
        plan_brand_name,
        state_code,
        product_code
    from {{ ref('dim_plans') }}
),
final as (
    -- Add plan attributes and calculate PMPM ratios
    select
        -- Grain
        pmm.plan_id,
        pmm.month_start_date,
        -- Plan natural key
        p.plan_brand_code,
        p.aid_category_code,
        p.plan_benefit_package_code,
        -- Plan attributes
        p.plan_brand_name,
        p.state_code,
        p.product_code,
        -- Financial measures
        pmm.service_month_paid_amount,
        pmm.payment_month_paid_amount,
        -- Enrollment measures
        cast(pmm.member_month_count as integer) as member_month_count,
        pmm.fractional_member_months,
        -- PMPM measures: non-additive; recompute from amounts and denominators when rolling up
        pmm.service_month_paid_amount / nullif(pmm.member_month_count, 0) as service_month_pmpm_member_count,
        pmm.service_month_paid_amount / nullif(pmm.fractional_member_months, 0) as service_month_pmpm_fractional_member,
        pmm.payment_month_paid_amount / nullif(pmm.member_month_count, 0) as payment_month_pmpm_member_count,
        pmm.payment_month_paid_amount / nullif(pmm.fractional_member_months, 0) as payment_month_pmpm_fractional_member
    from plan_month_measures pmm
    left join plans p
        on pmm.plan_id = p.plan_id
)
select * from final
