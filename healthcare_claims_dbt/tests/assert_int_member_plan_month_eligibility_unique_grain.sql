select
    member_id,
    plan_id,
    month,
    count(*) as row_count
from {{ ref('int_member_plan_month_eligibility') }}
group by
    member_id,
    plan_id,
    month
having count(*) > 1
