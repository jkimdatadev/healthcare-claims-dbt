with source_exposure as (
    select
        member_id,
        month_start_date,
        sum(member_month_exposure) as expected_exposure
    from {{ ref('fct_member_plan_month') }}
    group by
        member_id,
        month_start_date
),
actual_exposure as (
    select
        member_id,
        month_start_date,
        eligible_days,
        days_in_month,
        member_month_exposure
    from {{ ref('fct_member_month') }}
),
final as (
    select
        s.member_id as source_member_id,
        a.member_id as actual_member_id,
        s.month_start_date as source_month_start_date,
        a.month_start_date as actual_month_start_date,
        s.expected_exposure,
        a.member_month_exposure as actual_exposure,
        a.eligible_days,
        a.days_in_month
    from source_exposure s
    full outer join actual_exposure a
        on s.member_id = a.member_id
        and s.month_start_date = a.month_start_date
)
select *
from final
where source_member_id is null
    or actual_member_id is null
    or abs(expected_exposure - actual_exposure) > 0.000001
    or abs(actual_exposure - cast(eligible_days as double) / nullif(days_in_month, 0)) > 0.000001
    or actual_exposure is null
    or eligible_days is null
    or days_in_month is null
    or days_in_month = 0