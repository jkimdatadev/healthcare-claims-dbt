with source as (
    select * from {{ ref('raw_medical_claim_lines') }}
),
renamed as (
    select
        upper(nullif(trim(claim_id), '')) as claim_id,
        claim_line_number,
        upper(nullif(trim(member_id), '')) as member_id,
        upper(nullif(trim(claim_type_code), '')) as claim_type_code,
        upper(nullif(trim(claim_status_code), '')) as claim_status_code,
        cast(billing_provider_npi as varchar) as billing_provider_npi,
        cast(rendering_provider_npi as varchar) as rendering_provider_npi,
        upper(nullif(trim(billing_provider_type), '')) as billing_provider_type,
        cast(bill_type_code as varchar) as bill_type_code,
        service_from_date,
        service_to_date,
        received_date,
        paid_date,
        cast(place_of_service_code as varchar) as place_of_service_code,
        lpad(cast(revenue_code as varchar), 4, '0') as revenue_code,
        upper(nullif(trim(procedure_code), '')) as procedure_code,
        upper(nullif(trim(procedure_modifier), '')) as procedure_modifier,
        units,
        upper(nullif(trim(diagnosis_code_1), '')) as diagnosis_code_1,
        upper(nullif(trim(diagnosis_code_2), '')) as diagnosis_code_2,
        upper(nullif(trim(diagnosis_code_3), '')) as diagnosis_code_3,
        cast(billed_amount as decimal(12, 2)) as billed_amount,
        cast(allowed_amount as decimal(12, 2)) as allowed_amount,
        cast(paid_amount as decimal(12, 2)) as paid_amount,
        cast(member_responsibility_amount as decimal(12, 2)) as member_responsibility_amount,
        updated_at
    from source
)
select * from renamed