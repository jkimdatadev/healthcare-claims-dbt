select
    member_id,
    month_start_date,
    is_eligible_month_end,
    month_end_plan_id,
    is_dual_eligible_month_end,
    receives_ltss_month_end
from {{ ref('fct_member_month') }}
where (
    is_eligible_month_end = true
    and (
        month_end_plan_id is null
        or is_dual_eligible_month_end is null
        or receives_ltss_month_end is null
    )
)
or (
    is_eligible_month_end is distinct from true
    and (
        month_end_plan_id is not null
        or is_dual_eligible_month_end is not null
        or receives_ltss_month_end is not null
    )
)