/*
Verify that every enrolled plan-month in fct_member_plan_month has exactly one row
for each of the four provider types (HOSP, LAB, PHYS, SNF).
*/
with enrolled_plan_months as (
    select distinct
        plan_id,
        month_start_date
    from {{ ref('fct_member_plan_month') }}
),
provider_types as (
    select billing_provider_type
    from (values ('HOSP'), ('LAB'), ('PHYS'), ('SNF')) as pt (billing_provider_type)
),
expected_keys as (
    select
        epm.plan_id,
        epm.month_start_date,
        pt.billing_provider_type
    from enrolled_plan_months epm
    cross join provider_types pt
),
actual_keys as (
    select
        cv.plan_id,
        cv.month_start_date,
        cv.billing_provider_type
    from {{ ref('agg_plan_month_provider_type_claim_volume') }} cv
    inner join enrolled_plan_months epm
        on cv.plan_id = epm.plan_id
        and cv.month_start_date = epm.month_start_date
),
missing_rows as (
    select * from expected_keys
    except
    select * from actual_keys
),
unexpected_rows as (
    select * from actual_keys
    except
    select * from expected_keys
),
final as (
    select
        'missing_provider_type_row' as discrepancy_type,
        plan_id,
        month_start_date,
        billing_provider_type
    from missing_rows
    union all
    select
        'unexpected_provider_type' as discrepancy_type,
        plan_id,
        month_start_date,
        billing_provider_type
    from unexpected_rows
)
select * from final
