with source_data as (

    select *
    from {{ source('raw', 'cost_report') }}

),

renamed as (

    select
        "Provider CCN"                                  as ccn,
        "Hospital Name"                                  as hospital_name,
        "Street Address"                                 as street_address,
        "City"                                           as city,
        "State Code"                                     as state,
        "Zip Code"                                       as zip_code,
        "County"                                         as county,
        "Medicare CBSA Number"                           as medicare_cbsa,
        "Rural Versus Urban"                             as rural_urban,
        "CCN Facility Type"                              as ccn_facility_type,
        "Provider Type"                                  as provider_type,
        "Type of Control"                                as ownership_type,
        to_date("Fiscal Year Begin Date", 'MM/DD/YYYY')  as fiscal_year_begin_date,
        to_date("Fiscal Year End Date", 'MM/DD/YYYY')    as fiscal_year_end_date,
        "FTE - Employees on Payroll"                     as fte_employees,
        "Number of Interns and Residents (FTE)"          as interns_residents_fte,
        "Number of Beds"                                 as number_of_beds,
        "Total Bed Days Available"                       as total_bed_days_available,
        "Cost of Charity Care"                           as charity_care_cost,
        "Total Bad Debt Expense"                         as bad_debt_expense,
        "Cost of Uncompensated Care"                     as uncompensated_care_cost,
        "Total Unreimbursed and Uncompensated Care"      as total_unreimbursed_uncompensated_care,
        "Total Salaries From Worksheet A"                as total_salaries,
        "Overhead Non-Salary Costs"                      as overhead_non_salary_costs,
        "Depreciation Cost"                              as depreciation_cost,
        "Total Costs"                                    as total_costs,
        "Inpatient Total Charges"                        as inpatient_total_charges,
        "Outpatient Total Charges"                       as outpatient_total_charges,
        "Combined Outpatient + Inpatient Total Charges"  as total_charges,
        "Cash on Hand and in Banks"                      as cash_on_hand,
        "Total Current Assets"                           as total_current_assets,
        "Total Assets"                                   as total_assets,
        "Total Current Liabilities"                      as total_current_liabilities,
        "Total Long Term Liabilities"                    as total_long_term_liabilities,
        "Total Liabilities"                              as total_liabilities,
        "Total Fund Balances"                            as total_fund_balances,
        "Total Liabilities and Fund Balances"             as total_liabilities_and_fund_balances,
        "DRG Amounts Other Than Outlier Payments"        as drg_payments,
        "Outlier Payments For Discharges"                as outlier_payments,
        "Disproportionate Share Adjustment"              as dsh_adjustment,
        "Allowable DSH Percentage"                       as allowable_dsh_percentage,
        "Managed Care Simulated Payments"                as managed_care_simulated_payments
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
    hospital_name,
    street_address,
    city,
    state,
    zip_code,
    county,
    medicare_cbsa,
    rural_urban,
    ccn_facility_type,
    provider_type,
    ownership_type,
    fiscal_year_begin_date,
    fiscal_year_end_date,
    fte_employees,
    interns_residents_fte,
    number_of_beds,
    total_bed_days_available,
    charity_care_cost,
    bad_debt_expense,
    uncompensated_care_cost,
    total_unreimbursed_uncompensated_care,
    total_salaries,
    overhead_non_salary_costs,
    depreciation_cost,
    total_costs,
    inpatient_total_charges,
    outpatient_total_charges,
    total_charges,
    cash_on_hand,
    total_current_assets,
    total_assets,
    total_current_liabilities,
    total_long_term_liabilities,
    total_liabilities,
    total_fund_balances,
    total_liabilities_and_fund_balances,
    drg_payments,
    outlier_payments,
    dsh_adjustment,
    allowable_dsh_percentage,
    managed_care_simulated_payments
from deduped
where rn = 1
