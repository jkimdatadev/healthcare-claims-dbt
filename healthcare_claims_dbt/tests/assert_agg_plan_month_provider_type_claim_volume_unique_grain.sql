/* Validate uniqueness of the plan-month-provider-type grain */
select
    plan_id,
    month_start_date,
    billing_provider_type,
    count(*) as row_count
from {{ ref('agg_plan_month_provider_type_claim_volume') }}
group by
    plan_id,
    month_start_date,
    billing_provider_type
having count(*) > 1
