/*
Verify that each plan brand operates in exactly one state.
The plan natural key (plan_brand_code + aid_category_code + plan_benefit_package_code)
excludes state_code and relies on this assumption.
*/
with plans as (
    select
        plan_brand_code,
        state_code
    from {{ ref('stg_plans') }}
),
brands_with_multiple_states as (
    select
        plan_brand_code,
        count(distinct state_code) as state_count
    from plans
    group by plan_brand_code
    having count(distinct state_code) > 1
),
final as (
    select
        plan_brand_code,
        state_count
    from brands_with_multiple_states
)
select * from final