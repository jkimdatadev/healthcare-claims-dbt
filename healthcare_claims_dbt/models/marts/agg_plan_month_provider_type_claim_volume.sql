with qualifying_claim_lines as (
    -- Select paid claim lines with confirmed plan enrollment on the service date, through the analysis cutoff
    select
        claim_id,
        plan_id,
        service_from_month_start_date,
        billing_provider_type
    from {{ ref('fct_medical_claim_lines') }}
    where
        claim_status_code = 'PAID'
        and has_matching_eligibility
        and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
),
claim_volume as (
    -- Count claim lines and distinct claims for each plan, service month, and provider type
    select
        plan_id,
        service_from_month_start_date as month_start_date,
        billing_provider_type,
        count(*) as claim_line_count,
        count(distinct claim_id) as claim_count
    from qualifying_claim_lines
    group by
        plan_id,
        service_from_month_start_date,
        billing_provider_type
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
provider_types as (
    -- Define the four expected billing provider types
    select billing_provider_type
    from (values ('HOSP'), ('LAB'), ('PHYS'), ('SNF')) as pt (billing_provider_type)
),
row_keys as (
    -- Pair each enrolled plan-month with all four provider types; include claim-only combinations so no claims are dropped
    select
        pme.plan_id,
        pme.month_start_date,
        pt.billing_provider_type
    from plan_month_enrollment pme
    cross join provider_types pt
    union
    select
        plan_id,
        month_start_date,
        billing_provider_type
    from claim_volume
),
row_measures as (
    -- Join claim volume and enrollment measures to each plan, month, and provider type
    select
        rk.plan_id,
        rk.month_start_date,
        rk.billing_provider_type,
        coalesce(cv.claim_line_count, 0) as claim_line_count,
        coalesce(cv.claim_count, 0) as claim_count,
        coalesce(pme.member_month_count, 0) as member_month_count,
        coalesce(pme.fractional_member_months, 0) as fractional_member_months
    from row_keys rk
    left join claim_volume cv
        on rk.plan_id = cv.plan_id
        and rk.month_start_date = cv.month_start_date
        and rk.billing_provider_type = cv.billing_provider_type
    left join plan_month_enrollment pme
        on rk.plan_id = pme.plan_id
        and rk.month_start_date = pme.month_start_date
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
    -- Add plan attributes and calculate claim-volume rates per 1,000 member months
    select
        -- Grain
        rm.plan_id,
        rm.month_start_date,
        rm.billing_provider_type,
        -- Plan natural key
        p.plan_brand_code,
        p.aid_category_code,
        p.plan_benefit_package_code,
        -- Plan attributes
        p.plan_brand_name,
        p.state_code,
        p.product_code,
        -- Claim-volume measures
        cast(rm.claim_line_count as integer) as claim_line_count,
        cast(rm.claim_count as integer) as claim_count,
        -- Enrollment denominators: repeated on each provider-type row; do not sum across provider types
        cast(rm.member_month_count as integer) as member_month_count,
        rm.fractional_member_months,
        -- Rates: non-additive; recompute from summed counts and one denominator per plan-month
        cast(rm.claim_line_count as double) * 1000 / nullif(rm.member_month_count, 0) as claim_lines_per_1000_member_months,
        cast(rm.claim_count as double) * 1000 / nullif(rm.member_month_count, 0) as claims_per_1000_member_months
    from row_measures rm
    left join plans p
        on rm.plan_id = p.plan_id
)
select * from final
