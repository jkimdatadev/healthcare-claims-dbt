/*
Verify that service_to_date is not earlier than service_from_date for each medical claim line.
*/
select
    claim_id,
    claim_line_number,
    service_from_date,
    service_to_date
from {{ ref('fct_medical_claim_lines') }}
where service_to_date < service_from_date
