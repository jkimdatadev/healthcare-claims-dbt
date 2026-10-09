with member_months as (
    select
        member_id,
        month_start_date,
        last_eligible_date,
        is_eligible_month_end
    from {{ ref('fct_member_month') }}
),
expected_status as (
    select
        *,
        case
            when last_day(month_start_date) > cast('{{ var('analysis_through_date') }}' as date) then null
            when last_eligible_date = last_day(month_start_date) then true
            else false
        end as expected_is_eligible_month_end
    from member_months
)
select *
from expected_status
where is_eligible_month_end is distinct from expected_is_eligible_month_end