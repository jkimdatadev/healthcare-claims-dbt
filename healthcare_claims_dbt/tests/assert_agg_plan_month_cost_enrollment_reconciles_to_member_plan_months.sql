/*
Verify that enrollment measures reconcile to underlying member-plan-month records for each plan and month.
*/
with expected as (
    select
        plan_id,
        month_start_date,
        count(*) as expected_member_month_count,
        sum(member_month_exposure) as expected_fractional_member_months
    from {{ ref('fct_member_plan_month') }}
    group by
        plan_id,
        month_start_date
),
actual as (
    select
        plan_id,
        month_start_date,
        member_month_count as actual_member_month_count,
        fractional_member_months as actual_fractional_member_months
    from {{ ref('agg_plan_month_cost') }}
),
compared as (
    select
        coalesce(e.plan_id, a.plan_id) as plan_id,
        coalesce(e.month_start_date, a.month_start_date) as month_start_date,
        coalesce(e.expected_member_month_count, 0) as expected_member_month_count,
        a.actual_member_month_count,
        coalesce(e.expected_fractional_member_months, 0) as expected_fractional_member_months,
        a.actual_fractional_member_months,
        a.plan_id is null as is_missing_in_agg
    from expected e
    full outer join actual a
        on e.plan_id = a.plan_id
        and e.month_start_date = a.month_start_date
),
final as (
    select
        case
            when is_missing_in_agg then 'missing_in_agg'
            when actual_member_month_count is null
                or actual_member_month_count <> expected_member_month_count
                then 'member_month_count_mismatch'
            else 'fractional_member_months_mismatch'
        end as discrepancy_type,
        plan_id,
        month_start_date,
        expected_member_month_count,
        actual_member_month_count,
        expected_fractional_member_months,
        actual_fractional_member_months
    from compared
    where
        is_missing_in_agg
        or actual_member_month_count is null
        or actual_fractional_member_months is null
        or actual_member_month_count <> expected_member_month_count
        or abs(actual_fractional_member_months - expected_fractional_member_months) > 1e-9
)
select * from final
