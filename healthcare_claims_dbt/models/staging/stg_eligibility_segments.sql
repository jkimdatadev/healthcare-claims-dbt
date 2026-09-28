with source as (
    select * from {{ ref('raw_eligibility_segments') }}
),
renamed as (
    select 
        upper(nullif(trim(eligibility_segment_id), '')) as eligibility_segment_id,
        upper(nullif(trim(member_id), '')) as member_id,
        upper(nullif(trim(plan_id), '')) as plan_id,
        cast(effective_date as date) as effective_date,
        cast(term_date as date) as term_date,
        cast(updated_at as timestamp) as updated_at
    from source
)
select * from renamed
