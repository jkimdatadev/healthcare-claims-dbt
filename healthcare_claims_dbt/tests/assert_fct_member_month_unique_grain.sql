select
    member_id,
    month_start_date,
    count(*) as row_count
from {{ ref('fct_member_month') }}
group by
    member_id,
    month_start_date
having count(*) > 1