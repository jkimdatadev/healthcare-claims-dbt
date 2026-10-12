/*
Verify that plan_brand_code and plan_brand_name map one-to-one.
Flags codes used for more than one brand name and brand names with more than one code.
*/
with plans as (
    select
        plan_brand_code,
        plan_brand_name
    from {{ ref('stg_plans') }}
),
codes_with_multiple_names as (
    select
        plan_brand_code,
        count(distinct plan_brand_name) as distinct_value_count
    from plans
    group by plan_brand_code
    having count(distinct plan_brand_name) > 1
),
names_with_multiple_codes as (
    select
        plan_brand_name,
        count(distinct plan_brand_code) as distinct_value_count
    from plans
    group by plan_brand_name
    having count(distinct plan_brand_code) > 1
),
final as (
    select
        'code_with_multiple_names' as discrepancy_type,
        plan_brand_code,
        null as plan_brand_name,
        distinct_value_count
    from codes_with_multiple_names
    union all
    select
        'name_with_multiple_codes' as discrepancy_type,
        null as plan_brand_code,
        plan_brand_name,
        distinct_value_count
    from names_with_multiple_codes
)
select * from final
