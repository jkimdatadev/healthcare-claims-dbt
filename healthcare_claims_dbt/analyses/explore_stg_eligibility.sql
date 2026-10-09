/*Profile eligibility data range and open-ended segments */
select
    min(effective_date) as min_effective_date,
    max(effective_date) as max_effective_date,
    max(term_date) as max_term_date,
    count(*) as segment_count,
    count(*) filter (where term_date is null) as open_segment_count
from {{ ref('stg_eligibility_segments') }}

/*Compare eligibility and claims date ranges */
select
    (select min(effective_date) from {{ ref('stg_eligibility_segments') }}) as eligibility_start_date,
    (select max(coalesce(term_date, effective_date)) from {{ ref('stg_eligibility_segments') }}) as eligibility_observed_end_date,
    (select min(service_from_date) from {{ ref('stg_medical_claim_lines') }}) as claims_start_date,
    (select max(service_to_date) from {{ ref('stg_medical_claim_lines') }}) as claims_end_date