select 
    (select count(*) from {{ ref('stg_medical_claim_lines') }}) as source_row_count,
    (select count() from {{ ref('int_medical_claim_lines_enriched') }}) as enriched_row_count
where
    (select count(*) from {{ ref('stg_medical_claim_lines') }})
    !=
    (select count() from {{ ref('int_medical_claim_lines_enriched') }})