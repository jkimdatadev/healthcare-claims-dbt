with eligibility_segments as (
    select * from {{ ref('stg_eligibility_segments') }}
),
plans as (
    select * from {{ ref('stg_plans') }}
),
bounded_segments as (
    select
        member_id,
        plan_id,
        effective_date,
        term_date,
        least(
            coalesce(
                term_date,
                cast('{{ var('analysis_through_date') }}' as date)
            ),
            cast('{{ var('analysis_through_date') }}' as date)
        ) as expansion_end_date
    from eligibility_segments
),
segment_months as (
    select
        member_id,
        plan_id,
        cast(month_timestamp as date) as month_start_date,
        effective_date,
        term_date,
        expansion_end_date,
        least(expansion_end_date, last_day(cast(month_timestamp as date))) as segment_month_end_date
    from bounded_segments
    cross join lateral generate_series(
        date_trunc('month', effective_date),
        date_trunc('month', expansion_end_date),
        interval '1 month'
    ) as generated_months(month_timestamp)
),
monthly_eligible_days as (
    select
        *,
        datediff(
            'day',
            greatest(effective_date, month_start_date),
            segment_month_end_date
        ) + 1 as month_eligible_days
    from segment_months
),
member_plan_months as (
    select
        member_id,
        plan_id,
        month_start_date,
        day(last_day(month_start_date)) as days_in_month,
        sum(month_eligible_days) as eligible_days,
        count(*) > 1 as has_multiple_segments,
        max(segment_month_end_date) as last_eligible_date
    from monthly_eligible_days
    group by
        member_id,
        plan_id,
        month_start_date
),
final as (
    select
        mpm.member_id,
        mpm.plan_id,
        mpm.month_start_date,
        mpm.eligible_days,
        mpm.days_in_month,
        cast(mpm.eligible_days as double) / mpm.days_in_month as member_month_exposure,
        case when p.product_code = 'DSNP' then true else false end as is_dual_eligible,
        case when p.aid_category_code = 'LTC' then true else false end as receives_ltss,
        mpm.has_multiple_segments,
        mpm.last_eligible_date
    from member_plan_months mpm
    left join plans p
        on mpm.plan_id = p.plan_id
)
select * from final
