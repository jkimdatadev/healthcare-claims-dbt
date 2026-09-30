select
    a.member_id,
    a.eligibility_segment_id as a_segment_id,
    a.effective_date as a_effective_date,
    a.term_date as a_term_date, -- term_date is inclusive; null term_date represents an active segment
    b.eligibility_segment_id as b_segment_id,
    b.effective_date as b_effective_date,
    b.term_date as b_term_date
from {{ ref('stg_eligibility_segments') }} a
inner join {{ ref('stg_eligibility_segments') }} b
    on a.member_id = b.member_id
    and a.eligibility_segment_id != b.eligibility_segment_id
    and a.effective_date <= b.effective_date
    and coalesce(a.term_date, '2999-12-31') >= b.effective_date
order by member_id, a_segment_id, b_segment_id
