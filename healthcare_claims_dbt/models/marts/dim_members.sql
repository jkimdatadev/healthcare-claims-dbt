with members as (
    select
        member_id,
        first_name,
        last_name,
        date_of_birth,
        gender_code,
        residence_state_code,
        created_at,
        updated_at
    from {{ ref('stg_members') }}
),
eligibility_ranked as (
    select
        member_id,
        plan_id,
        effective_date,
        term_date,
        row_number() over (
            partition by member_id
            order by effective_date desc, eligibility_segment_id desc
        ) as rn
    from {{ ref('stg_eligibility_segments') }}
),
eligibility_summary as (
    select
        member_id,
        min(effective_date) as earliest_eligibility_effective_date,
        max(case when rn = 1 then effective_date end) as latest_eligibility_effective_date,
        max(case when rn = 1 then term_date end) as latest_eligibility_term_date,
        max(case when rn = 1 then plan_id end) as latest_plan_id
    from eligibility_ranked
    group by member_id
),
final as (
    select
        m.member_id,
        m.first_name,
        m.last_name,
        m.date_of_birth,
        m.gender_code,
        m.residence_state_code,
        m.created_at,
        m.updated_at,
        es.earliest_eligibility_effective_date,
        es.latest_eligibility_effective_date,
        es.latest_eligibility_term_date,
        es.latest_plan_id
    from members m
    left join eligibility_summary es
        on m.member_id = es.member_id
)
select * from final
