/*
Verify that financial amounts in fct_medical_claim_lines match those in int_medical_claim_lines_enriched
for each claim line, protecting against unintended changes to financial values.
*/
with source_amounts as (
    select
        claim_id,
        claim_line_number,
        billed_amount,
        allowed_amount,
        paid_amount,
        member_responsibility_amount
    from {{ ref('int_medical_claim_lines_enriched') }}
),
fact_amounts as (
    select
        claim_id,
        claim_line_number,
        billed_amount,
        allowed_amount,
        paid_amount,
        member_responsibility_amount
    from {{ ref('fct_medical_claim_lines') }}
),
source_only_rows as (
    select * from source_amounts
    except
    select * from fact_amounts
),
fact_only_rows as (
    select * from fact_amounts
    except
    select * from source_amounts
),  
mismatches as (
    select * from source_only_rows
    union all
    select * from fact_only_rows
)
select * from mismatches
