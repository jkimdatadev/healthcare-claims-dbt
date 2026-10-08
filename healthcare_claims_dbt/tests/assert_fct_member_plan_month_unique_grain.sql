select
    member_id,
    plan_id,
    month_start_date,
    count(*) as row_count
from {{ ref('fct_member_plan_month') }}
group by
    member_id,
    plan_id,
    month_start_date
having count(*) > 1
 