select
    eligibility_segment_id,
    effective_date,
    term_date
from {{ ref('stg_eligibility_segments') }}
where term_date < effective_date
