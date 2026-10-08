select
    member_id,
    plan_id,
    month_start_date,
    eligible_days
from {{ ref('fct_member_plan_month') }}
where
    eligible_days < 1 
    or eligible_days > day(last_day(month_start_date))
