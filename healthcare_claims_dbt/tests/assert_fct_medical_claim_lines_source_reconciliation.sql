/*
Purpose of source-to-fact reconciliation:
1. Detect future changes to the fact model that accidentally omit, introduce, or modify claim-line keys.
2. Detect inconsistencies when the upstream intermediate model changes but the downstream fact has not been rebuilt.

The current fact model preserves source keys by design, but this test
ensures that the relationship continues to hold over time.
*/
with source_keys as (
    select
        claim_id,
        claim_line_number
    from {{ ref('int_medical_claim_lines_enriched') }}
),
fact_keys as (
    select
        claim_id,
        claim_line_number
    from {{ ref('fct_medical_claim_lines') }}
),
missing_in_fact as (
    select * from source_keys
    except
    select * from fact_keys
),
unexpected_in_fact as (
    select * from fact_keys
    except
    select * from source_keys
),
final as (
    select
        'missing_in_fact' as discrepancy_type,
        claim_id,
        claim_line_number
    from missing_in_fact
    union all
    select
        'unexpected_in_fact' as discrepancy_type,
        claim_id,
        claim_line_number
    from unexpected_in_fact
)
select * from final
