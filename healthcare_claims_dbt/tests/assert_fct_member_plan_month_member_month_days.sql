select
    member_id,
    month_start_date,
    count(*) as plan_count,
    sum(eligible_days) as total_eligible_days,
    max(days_in_month) as days_in_month,
    sum(member_month_exposure) as total_exposure
from {{ ref('fct_member_plan_month') }}
group by
    member_id,
    month_start_date
having sum(eligible_days) > max(days_in_month)
