/* Validate uniqueness of the plan-month grain */
select
    plan_id,
    month_start_date,
    count(*) as row_count
from {{ ref('agg_plan_month_cost') }}
group by
    plan_id,
    month_start_date
having count(*) > 1