/*
Verify that payment-month paid amounts reconcile to underlying medical claims
for each plan and month.
*/
with expected as (
    select
        plan_id,
        cast(date_trunc('month', paid_date) as date) as month_start_date,
        sum(paid_amount) as expected_paid_amount
    from {{ ref('fct_medical_claim_lines') }}
    where
        claim_status_code = 'PAID'
        and has_matching_eligibility
        and service_from_date <= cast('{{ var("analysis_through_date") }}' as date)
    group by
        plan_id,
        cast(date_trunc('month', paid_date) as date)
),
actual as (
    select
        plan_id,
        month_start_date,
        payment_month_paid_amount as actual_paid_amount
    from {{ ref('agg_plan_month_cost') }}
),
compared as (
    select
        coalesce(e.plan_id, a.plan_id) as plan_id,
        coalesce(e.month_start_date, a.month_start_date) as month_start_date,
        coalesce(e.expected_paid_amount, 0) as expected_paid_amount,
        a.actual_paid_amount,
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
            else 'amount_mismatch'
        end as discrepancy_type,
        plan_id,
        month_start_date,
        expected_paid_amount,
        actual_paid_amount
    from compared
    where
        is_missing_in_agg
        or actual_paid_amount is null
        or abs(actual_paid_amount - expected_paid_amount) > 0.005
)
select * from final