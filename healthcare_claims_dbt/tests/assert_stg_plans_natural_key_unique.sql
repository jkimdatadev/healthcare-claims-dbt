/*
Verify that the plan natural key is unique.
Natural key: plan_brand_code + aid_category_code + plan_benefit_package_code.
Group by treats nulls as equal, so Medicaid plans with a null benefit package are compared on brand and aid category.
*/
with plans as (
    select
        plan_id,
        plan_brand_code,
        aid_category_code,
        plan_benefit_package_code
    from {{ ref('stg_plans') }}
),
duplicate_keys as (
    select
        plan_brand_code,
        aid_category_code,
        plan_benefit_package_code,
        count(*) as plan_count,
        string_agg(plan_id, ', ' order by plan_id) as plan_ids
    from plans
    group by
        plan_brand_code,
        aid_category_code,
        plan_benefit_package_code
    having count(*) > 1
),
final as (
    select
        plan_brand_code,
        aid_category_code,
        plan_benefit_package_code,
        plan_count,
        plan_ids
    from duplicate_keys
)
select * from final
