/*Inspect raw schema */
select
    column_name,
    data_type
from information_schema.columns
where table_name = 'raw_medical_claim_lines'
order by ordinal_position

/*Check whether claim_id + claim_line_number is unique */
select
    claim_id,
    claim_line_number,
    count(*) as row_count
from {{ ref('raw_medical_claim_lines') }}
group by
    claim_id,
    claim_line_number
having count(*) > 1

/*Check whether claim_id alone is unique */
select
    claim_id,
    count(*) as line_count
from {{ ref('raw_medical_claim_lines') }}
group by claim_id
having count(*) > 1
order by line_count desc

/*Inspect provider fields */
select distinct
    billing_provider_npi,
    rendering_provider_npi,
    billing_provider_type
from {{ ref('raw_medical_claim_lines') }}
order by billing_provider_type

/*Check rendering provider NPI nullability */
select
    count(*) as total_rows,
    count(rendering_provider_npi) as populated_rows,
    count(*) - count(rendering_provider_npi) as null_rows
from {{ ref('raw_medical_claim_lines') }}

/*Profile billing provider type */
select
    billing_provider_type,
    count(*) as row_count
from {{ ref('raw_medical_claim_lines') }}
group by billing_provider_type
order by billing_provider_type

/*Check units range and nonpositive values */
select
    min(units) as min_units,
    max(units) as max_units,
    count(*) filter (where units <= 0) as nonpositive_rows
from {{ ref('raw_medical_claim_lines') }}

/*Inspect staged medical claim lines */
select *
from {{ ref('stg_medical_claim_lines') }}
limit 100
