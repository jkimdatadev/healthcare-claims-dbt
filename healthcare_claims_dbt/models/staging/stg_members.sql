with source as (
    select * from {{ ref('raw_members')}}
),
renamed as (
    select
        upper(trim(member_id))                  as member_id,
        nullif(trim(first_name), '')            as first_name,
        nullif(trim(last_name), '')             as last_name,
        cast(date_of_birth as date)             as date_of_birth,
        upper(nullif(trim(gender_code), ''))    as gender_code,
        upper(nullif(trim(state_code), ''))     as state_code,
        cast(created_at as timestamp)           as created_at,
        cast(updated_at as timestamp)           as updated_at
    from source
)
select * from renamed

