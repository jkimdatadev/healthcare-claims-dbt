# Healthcare Claims Analytics | dbt

An end-to-end analytics engineering project using dbt Core and SQL to transform synthetic Medicaid and Medicare data into tested, analysis-ready datasets for enrollment, medical cost, and claim-volume reporting.

It translates healthcare payer business rules into reliable analytical models, with particular attention to eligibility, service-date plan matching, and measures that cannot simply be summed or averaged.

The synthetic data was iteratively refined to reflect realistic healthcare payer scenarios, including partial-month enrollment, plan changes, denied claims, and payments after the analysis cutoff. It includes 1,500 members, 32 plans, 2,447 eligibility segments, and 42,163 medical claim lines.

## Project highlights

- **Data modeling:** Layered dbt transformations with service-date plan matching, fractional enrollment exposure, and consistent analytical measures.
- **Data validation:** 157 automated tests, cross-layer reconciliations, and documented business rules and model specifications.
- **Healthcare analytics:** Enrollment, medical cost, PMPM, and claim-volume reporting across Medicaid and Medicare plans.

## Architecture

```text
Raw Seeds (raw_*)
       |
       v
Staging (stg_*)
       |
       v
Intermediate (int_*) [where needed]
       |
       v
Marts
  ├── Facts (fct_*)
  ├── Dimensions (dim_*)
  └── Aggregates (agg_*)
```

The diagram illustrates the general model layers; marts can draw directly from staging or intermediate models, with dbt managing dependencies and execution order.

## Data model

### Facts and dimensions

| Model | Grain | Purpose |
|---|---|---|
| `fct_member_plan_month` | member + plan + month | Eligible days and fractional member-month exposure; the enrollment source for all aggregates |
| `fct_member_month` | member + month | Simpler member-level enrollment, with the plan and classifications on the calendar month-end |
| `fct_medical_claim_lines` | claim line | Every claim line, including denied and unmatched lines, with plan attribution from the service date |
| `dim_members` | member | Member attributes and an eligibility history summary |
| `dim_plans` | plan | Plan attributes and the plan natural key |

### Aggregates

| Model | Grain | Purpose |
|---|---|---|
| `agg_plan_month_cost` | plan + month | Paid amounts by service month and payment month, member months, and four PMPM ratios |
| `agg_plan_month_provider_type_claim_volume` | plan + service month + billing provider type | Claim line and claim counts, member months, and rates per 1,000 member months |

## Analytical applications

The resulting datasets support healthcare payer analysis, including:

- **Medical cost:** Compare paid medical costs and PMPM across plans and service months.
- **Payment trends:** Analyze differences between service-month and payment-month spending.
- **Claim volume:** Evaluate paid claim activity by billing provider type relative to enrollment.

## Key design decisions

**Eligibility and exposure**
- Eligibility term dates are inclusive; a member cannot have overlapping segments across plans. Open-ended segments are capped at `analysis_through_date` (2026-06-30).
- Fractional member-month exposure is `eligible_days / days_in_month`, without rounding (e.g., 15 of 30 days = 0.5 member months).

**Month-end status**
- `fct_member_month` uses the calendar month-end for plan and eligibility status; `is_eligible_month_end` is null for incomplete months, not false.

**Service-date plan matching**
- Claim lines are matched to the member's plan on the service date. Unmatched lines remain flagged in the claims fact but are excluded from plan-level aggregates.

**Plan identity**
- `plan_id` is the primary key; the natural key combines `plan_brand_code`, `aid_category_code`, and `plan_benefit_package_code`. The benefit package (CMS contract and PBP number) distinguishes concurrent DSNP plans that otherwise share the same classifications.

**Cost reporting**
- Service-month reporting assigns paid costs to service dates; payment-month reporting assigns the same costs to payment dates, including runout after the analysis cutoff. Total paid amounts reconcile.
- PMPM ratios are nonadditive; rollups recalculate them from total paid amounts and the appropriate member-month denominator.

**Claim volume**
- Each enrolled plan-month includes HOSP, LAB, PHYS, and SNF rows, including zero-claim combinations.
- Member-month denominators repeat by provider type and must not be summed across types.
- Counts represent claim lines and distinct claims, not clinical encounters; units are excluded because their meaning varies by provider type.

## Testing

Every model has generic tests (`not_null`, `unique`, `relationships`, `accepted_values`) where they apply. Singular tests cover the rules generic tests can't express:

- **Reconciliation between layers**: aggregate totals match the facts they come from, plan-month by plan-month, in both directions.
- **Formula checks**: every ratio matches its formula, and is null exactly when its denominator is zero.
- **Completeness**: every enrolled plan-month has all four provider-type rows.
- **Business rules**: no overlapping eligibility, eligible days within the month, consistent month-end columns, and a unique plan natural key.

Selected tests were deliberately break-tested by introducing model changes and confirming the tests failed as expected.

**Latest full build:** 157 tests passed, with 173 operations completed and no warnings or errors.

## Assumptions and scope

- All data is synthetic. Claim lines are produced by `healthcare_claims_dbt/scripts/generate_raw_medical_claim_lines.py`.
- A member is in only one plan at a time. Combined Medicare-Medicaid benefits are modeled as a single plan (DSNP).
- Plan attributes are static, without contract-year versioning; each plan brand operates in one state.
- No IBNR (incurred but not reported) adjustment is applied; recent service months may understate ultimate costs.
- Scope: Medicaid (MCD) and Medicare (DSNP, MA) plans in DE, NJ, NY, and PA.

## How to run

**Requirements:** Python, dbt-core 1.12, and dbt-duckdb 1.11.

1. Clone the repository and move into the dbt project folder:

   ```bash
   git clone https://github.com/jkimdatadev/healthcare-claims-dbt.git
   cd healthcare-claims-dbt/healthcare_claims_dbt
   ```

2. Install dbt with the DuckDB adapter:

   ```bash
   pip install "dbt-core==1.12.5" "dbt-duckdb==1.11.0"
   ```

3. Add a profile to `~/.dbt/profiles.yml`. The profile name must match `profile:` in `dbt_project.yml`:

   ```yaml
   healthcare_claims_dbt:
     target: dev
     outputs:
       dev:
         type: duckdb
         path: dev.duckdb
   ```

4. Check the connection, then load the seeds, build all models, and run all tests:

   ```bash
   dbt debug
   dbt build
   ```

## About

Built by **Jason Kim** as an analytics engineering portfolio project.

[GitHub profile](https://github.com/jkimdatadev)
