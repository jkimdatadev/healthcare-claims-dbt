select
    member_id,
    plan_id,
    month_start_date,
    eligible_days,
    last_eligible_date
from {{ ref('fct_member_plan_month') }}
where
    /*Last eligible date must fall within the month and accommodate all eligible days */
    last_eligible_date > last_day(month_start_date)
    or last_eligible_date < month_start_date + eligible_days - 1