with source as (
    select * from {{ ref('stg_eligibility_segments') }}
 ),
bounded as (
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
    from source
),
expanded as (
    select
        member_id,
        plan_id,
        cast(month_timestamp as date) as month,
        effective_date,
        term_date,
        expansion_end_date
    from bounded
    cross join lateral generate_series(
        date_trunc('month', effective_date),
        date_trunc('month', expansion_end_date),
        interval '1 month'
    ) as generated_months(month_timestamp)
),
derived_days as (
    select
        *,
        -- greatest(effective_date, month) as month_eligible_start_date,
        -- least(expansion_end_date, last_day(month)) as month_eligible_end_date
        datediff(
            'day',
            greatest(effective_date, month),
            least(expansion_end_date, last_day(month))
        ) + 1 as month_eligible_days
    from expanded
),
aggregated as (
    select
        member_id,
        plan_id,
        month,
        sum(month_eligible_days) as eligible_days,
        count(*) > 1 as has_multiple_segments
    from derived_days
    group by
        member_id,
        plan_id,
        month
)
select * from aggregated
