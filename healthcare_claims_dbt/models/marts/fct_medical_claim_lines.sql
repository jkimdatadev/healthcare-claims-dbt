with claim_lines_enriched as (
    select * from {{ ref('int_medical_claim_lines_enriched') }}
),
final as (
    select
        -- Claim grain
        claim_id,
        claim_line_number,
        -- Member and eligibility
        member_id,
        eligibility_segment_id,
        plan_id,
        has_matching_eligibility,
        -- Plan classification
        state_code,
        product_code,
        aid_category_code,
        -- Claim classification
        claim_type_code,
        claim_status_code,
        -- Service dates
        service_from_date,
        cast(date_trunc('month', service_from_date) as date) as service_from_month_start_date,
        service_to_date,
        -- Processing and audit dates
        received_date,
        paid_date,
        updated_at,
        -- Financial measures
        billed_amount,
        allowed_amount,
        paid_amount,
        member_responsibility_amount,
        -- Provider and service details
        billing_provider_npi,
        rendering_provider_npi,
        billing_provider_type,
        bill_type_code,
        place_of_service_code,
        revenue_code,
        procedure_code,
        procedure_modifier,
        units,
        -- Diagnoses
        diagnosis_code_1,
        diagnosis_code_2,
        diagnosis_code_3
    from claim_lines_enriched
)
select * from final
