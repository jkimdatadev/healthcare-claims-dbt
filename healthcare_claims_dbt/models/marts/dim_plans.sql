select
    plan_id,
    plan_brand_code,
    aid_category_code,
    plan_benefit_package_code,
    plan_brand_name,
    state_code,
    product_code,
    program_type_code,
    medicare_status_code,
    coverage_type_code,
    effective_date,
    term_date,
    updated_at
from {{ ref('stg_plans') }}
