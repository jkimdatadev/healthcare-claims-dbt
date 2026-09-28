with source as (
    select * from {{ ref('raw_plans') }}
),
renamed as (
    select
        upper(nullif(trim(plan_id), '')) as plan_id,
        nullif(trim(plan_brand_name), '') as plan_brand_name,
        upper(nullif(trim(product_code), '')) as product_code,
        upper(nullif(trim(program_type_code), '')) as program_type_code,
        upper(nullif(trim(state_code), '')) as state_code,
        upper(nullif(trim(medicare_status_code), '')) as medicare_status_code,
        upper(nullif(trim(aid_category_code), '')) as aid_category_code,
        upper(nullif(trim(coverage_type_code), '')) as coverage_type_code,
        cast(effective_date as date) as effective_date,
        cast(term_date as date) as term_date,
        cast(updated_at as timestamp) as updated_at
    from source
)
select * from renamed
