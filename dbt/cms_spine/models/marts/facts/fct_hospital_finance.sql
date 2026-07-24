-- Grain: one row per hospital (stg_cost_report is already deduped to the
-- latest fiscal year per CCN).
with cost_report as (

    select *
    from {{ ref('stg_cost_report') }}

),

hospitals as (

    select ccn, hospital_key
    from {{ ref('dim_hospital') }}

)

select
    h.hospital_key,
    c.fiscal_year_begin_date,
    c.fiscal_year_end_date,
    c.number_of_beds,
    c.total_bed_days_available,
    c.total_costs,
    c.total_charges,
    c.inpatient_total_charges,
    c.outpatient_total_charges,
    c.cost_to_charge_ratio,
    c.charity_care_cost,
    c.bad_debt_expense,
    c.uncompensated_care_cost,
    c.total_unreimbursed_uncompensated_care,
    c.net_income,
    c.net_income_from_service_to_patients,
    c.total_assets,
    c.total_liabilities,
    c.total_fund_balances,
    c.net_patient_revenue,
    -- NULL when cost_to_charge_ratio itself is NULL (unknown, not an
    -- outlier); true/false only when we actually have a value to judge.
    -- A few of these are implausible (CMS reporting errors upstream in
    -- total_charges, not something we can correct here); others near 1-2x
    -- are plausible for hospitals that don't bill fee-for-service (e.g.
    -- Kaiser Permanente). Flagged, not excluded or capped, so the raw
    -- reported figures stay intact for whoever queries this table.
    case
        when c.cost_to_charge_ratio is null then null
        else c.cost_to_charge_ratio < 0 or c.cost_to_charge_ratio > 1
    end as is_ccr_outlier
from cost_report c
inner join hospitals h on c.ccn = h.ccn
