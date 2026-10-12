/*
Verify that dim_members contains the same member IDs as stg_members.
Duplicates are covered by the unique test on member_id.
*/
with stg_member_keys as (
    select member_id
    from {{ ref('stg_members') }}
),
dim_member_keys as (
    select member_id
    from {{ ref('dim_members') }}
),
missing_in_dim as (
    select member_id
    from stg_member_keys
    except
    select member_id
    from dim_member_keys
),
unexpected_in_dim as (
    select member_id
    from dim_member_keys
    except
    select member_id
    from stg_member_keys
),
final as (
    select
        'missing_in_dim' as discrepancy_type,
        member_id
    from missing_in_dim
    union all
    select
        'unexpected_in_dim' as discrepancy_type,
        member_id
    from unexpected_in_dim
)
select * from final
