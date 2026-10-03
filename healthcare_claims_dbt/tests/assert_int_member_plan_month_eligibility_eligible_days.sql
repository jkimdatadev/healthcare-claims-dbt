select
    member_id,
    plan_id,
    month,
    eligible_days
from {{ ref('int_member_plan_month_eligibility') }}
where
    eligible_days < 1 
    or eligible_days > day(last_day(month))
