with member_plan_months as (
    select * from {{ ref('fct_member_plan_month') }}
),
member_months as (
    select
        member_id,
        month_start_date,
        sum(eligible_days) as eligible_days,
        max(days_in_month) as days_in_month,
        sum(member_month_exposure) as member_month_exposure,
        count(distinct plan_id) as plan_count,
        count(*) > 1 as has_multiple_plans,
        max(last_eligible_date) as last_eligible_date,
        case
            when last_day(month_start_date) > cast('{{ var('analysis_through_date') }}' as date) then null
            else max(last_eligible_date) = last_day(month_start_date)
        end as is_eligible_month_end,
        max(
            case
                when last_eligible_date = last_day(month_start_date)
                    and last_day(month_start_date) <= cast('{{ var('analysis_through_date') }}' as date)
                then plan_id
            end
        ) as month_end_plan_id,
        max(
            case
                when last_eligible_date = last_day(month_start_date)
                    and last_day(month_start_date) <= cast('{{ var('analysis_through_date') }}' as date)
                then is_dual_eligible
            end
        ) as is_dual_eligible_month_end,
        max(
            case
                when last_eligible_date = last_day(month_start_date)
                    and last_day(month_start_date) <= cast('{{ var('analysis_through_date') }}' as date)
                then receives_ltss
            end
        ) as receives_ltss_month_end
    from member_plan_months
    group by
        member_id,
        month_start_date
),
final as (
    select
        member_id,
        month_start_date,
        cast(eligible_days as integer) as eligible_days,
        cast(days_in_month as integer) as days_in_month,
        member_month_exposure,
        cast(plan_count as integer) as plan_count,
        has_multiple_plans,
        last_eligible_date,
        is_eligible_month_end,
        month_end_plan_id,
        is_dual_eligible_month_end,
        receives_ltss_month_end
    from member_months
)
select * from final
