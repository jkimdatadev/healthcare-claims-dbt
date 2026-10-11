/* Inspect fct_member_plan_month schema */
describe select * from main.fct_member_plan_month;

/* Inspect fct_member_month schema */
describe select * from main.fct_member_month;

/* Validate medical claim fact row count */
select
    (select count(*) from {{ ref('int_medical_claim_lines_enriched') }}) as source_rows,
    (select count(*) from {{ ref('fct_medical_claim_lines') }}) as fact_rows

/* Check medical claim fact grain uniqueness */
select
    claim_id,
    claim_line_number,
    count(*) as row_count
from {{ ref('fct_medical_claim_lines') }}
group by
    claim_id,
    claim_line_number
having count(*) > 1

