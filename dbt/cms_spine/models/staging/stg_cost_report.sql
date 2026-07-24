with source_data as (

    select *
    from {{ source('raw', 'cost_report') }}

),

renamed as (

    select
        "Provider CCN"                                  as ccn,
        -- Medicare's wage-index payment geography, not physical geography;
        -- disagrees with the HUD-crosswalk-derived cbsa_code ~42% of the
        -- time due to wage-index reclassification. See dim_hospital.
        "Medicare CBSA Number"                           as medicare_payment_cbsa,
        "Rural Versus Urban"                             as rural_urban,
        "Provider Type"                                  as provider_type,
        "Type of Control"                                as ownership_type,
        to_date("Fiscal Year Begin Date", 'MM/DD/YYYY')  as fiscal_year_begin_date,
        to_date("Fiscal Year End Date", 'MM/DD/YYYY')    as fiscal_year_end_date,
        "Number of Beds"                                 as number_of_beds,
        "Total Bed Days Available"                       as total_bed_days_available,
        "Cost of Charity Care"                           as charity_care_cost,
        "Total Bad Debt Expense"                         as bad_debt_expense,
        "Cost of Uncompensated Care"                     as uncompensated_care_cost,
        "Total Unreimbursed and Uncompensated Care"      as total_unreimbursed_uncompensated_care,
        "Total Costs"                                    as total_costs,
        "Inpatient Total Charges"                        as inpatient_total_charges,
        "Outpatient Total Charges"                       as outpatient_total_charges,
        "Combined Outpatient + Inpatient Total Charges"  as total_charges,
        "Total Assets"                                   as total_assets,
        "Total Liabilities"                              as total_liabilities,
        "Total Fund Balances"                            as total_fund_balances,
        -- DSH payments go to hospitals serving high volumes of low-income
        -- patients. NULL means the hospital doesn't qualify, not missing
        -- data -- treat as 0 when aggregating.
        "Disproportionate Share Adjustment"              as dsh_adjustment,
        "Allowable DSH Percentage"                       as allowable_dsh_percentage,
        "Cost To Charge Ratio"                           as cost_to_charge_ratio,
        "Net Income"                                     as net_income,
        "Net Income from Service to Patients"            as net_income_from_service_to_patients,
        -- Revenue denominator for charity/uncompensated-care ratios (Day 7).
        -- Net, not Total Patient Revenue: Total Patient Revenue is gross/
        -- pre-discount (avg ~$978M, ~5x avg Total Costs across raw.cost_report),
        -- while Net Patient Revenue = Total Patient Revenue - Contractual
        -- Allowance (verified exact on a sample) and tracks Total Costs at a
        -- comparable scale (avg ~$238M vs ~$193M) -- the one hospitals actually
        -- expect to collect.
        "Net Patient Revenue"                            as net_patient_revenue
    from source_data

),

deduped as (

    select
        *,
        row_number() over (
            partition by ccn
            order by fiscal_year_end_date desc
        ) as rn
    from renamed

)

select
    ccn,
    medicare_payment_cbsa,
    rural_urban,
    provider_type,
    ownership_type,
    fiscal_year_begin_date,
    fiscal_year_end_date,
    number_of_beds,
    total_bed_days_available,
    charity_care_cost,
    bad_debt_expense,
    uncompensated_care_cost,
    total_unreimbursed_uncompensated_care,
    total_costs,
    inpatient_total_charges,
    outpatient_total_charges,
    total_charges,
    total_assets,
    total_liabilities,
    total_fund_balances,
    dsh_adjustment,
    allowable_dsh_percentage,
    cost_to_charge_ratio,
    net_income,
    net_income_from_service_to_patients,
    net_patient_revenue
from deduped
where rn = 1
