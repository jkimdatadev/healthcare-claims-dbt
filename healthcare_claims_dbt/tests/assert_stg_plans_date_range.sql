select
    plan_id,
    effective_date,
    term_date
from {{ ref('stg_plans') }}
where term_date < effective_date
