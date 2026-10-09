with expected as (
    select
        member_id,
        month_start_date,
        plan_id as expected_plan_id,
        is_dual_eligible as expected_is_dual_eligible,
        receives_ltss as expected_receives_ltss
    from {{ ref('fct_member_plan_month') }}
    where last_eligible_date = last_day(month_start_date)
        and last_day(month_start_date) <= cast('{{ var('analysis_through_date') }}' as date)
),
actual as (
    select
        member_id,
        month_start_date,
        month_end_plan_id,
        is_dual_eligible_month_end,
        receives_ltss_month_end
    from {{ ref('fct_member_month') }}
    where month_end_plan_id is not null
),
final as (
    select
        e.member_id as expected_member_id,
        a.member_id as actual_member_id,
        coalesce(e.month_start_date, a.month_start_date) as month_start_date,
        e.expected_plan_id,
        a.month_end_plan_id,
        e.expected_is_dual_eligible,
        a.is_dual_eligible_month_end,
        e.expected_receives_ltss,
        a.receives_ltss_month_end
    from expected e
    full outer join actual a
        on e.member_id = a.member_id
        and e.month_start_date = a.month_start_date
)
select *
from final
where expected_member_id is null
    or actual_member_id is null
    or expected_plan_id is distinct from month_end_plan_id
    or expected_is_dual_eligible is distinct from is_dual_eligible_month_end
    or expected_receives_ltss is distinct from receives_ltss_month_end