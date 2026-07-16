"""Deduplicate raw.cost_report to one row per CCN (latest fiscal year end) into staging.cost_report_dedup.

Renames the business-critical columns to clean snake_case names at build
time (rather than ALTER TABLE on the existing table) so the staging layer
stays fully reproducible from raw on every rerun. The rest of the source's
~100 columns aren't needed yet and are left out until they are.
"""

import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# (source column in raw.cost_report, clean output name)
COLUMNS = [
    ("Provider CCN", "ccn"),
    ("Hospital Name", "hospital_name"),
    ("Street Address", "street_address"),
    ("City", "city"),
    ("State Code", "state"),
    ("Zip Code", "zip_code"),
    ("County", "county"),
    ("Medicare CBSA Number", "medicare_cbsa"),
    ("Rural Versus Urban", "rural_urban"),
    ("CCN Facility Type", "ccn_facility_type"),
    ("Provider Type", "provider_type"),
    ("Type of Control", "ownership_type"),
    ("Fiscal Year Begin Date", "fiscal_year_begin_date"),
    ("Fiscal Year End Date", "fiscal_year_end_date"),
    ("FTE - Employees on Payroll", "fte_employees"),
    ("Number of Interns and Residents (FTE)", "interns_residents_fte"),
    ("Number of Beds", "number_of_beds"),
    ("Total Bed Days Available", "total_bed_days_available"),
    ("Cost of Charity Care", "charity_care_cost"),
    ("Total Bad Debt Expense", "bad_debt_expense"),
    ("Cost of Uncompensated Care", "uncompensated_care_cost"),
    ("Total Unreimbursed and Uncompensated Care", "total_unreimbursed_uncompensated_care"),
    ("Total Salaries From Worksheet A", "total_salaries"),
    ("Overhead Non-Salary Costs", "overhead_non_salary_costs"),
    ("Depreciation Cost", "depreciation_cost"),
    ("Total Costs", "total_costs"),
    ("Inpatient Total Charges", "inpatient_total_charges"),
    ("Outpatient Total Charges", "outpatient_total_charges"),
    ("Combined Outpatient + Inpatient Total Charges", "total_charges"),
    ("Cash on Hand and in Banks", "cash_on_hand"),
    ("Total Current Assets", "total_current_assets"),
    ("Total Assets", "total_assets"),
    ("Total Current Liabilities", "total_current_liabilities"),
    ("Total Long Term Liabilities", "total_long_term_liabilities"),
    ("Total Liabilities", "total_liabilities"),
    ("Total Fund Balances", "total_fund_balances"),
    ("Total Liabilities and Fund Balances", "total_liabilities_and_fund_balances"),
    ("DRG Amounts Other Than Outlier Payments", "drg_payments"),
    ("Outlier Payments For Discharges", "outlier_payments"),
    ("Disproportionate Share Adjustment", "dsh_adjustment"),
    ("Allowable DSH Percentage", "allowable_dsh_percentage"),
    ("Managed Care Simulated Payments", "managed_care_simulated_payments"),
]


def main():
    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    select_list = ", ".join(f'cr."{src}" AS {alias}' for src, alias in COLUMNS)

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))
        conn.execute(text("DROP TABLE IF EXISTS staging.cost_report_dedup"))
        conn.execute(text(f"""
            CREATE TABLE staging.cost_report_dedup AS
            SELECT {select_list}
            FROM (
                SELECT
                    cr.*,
                    ROW_NUMBER() OVER (
                        PARTITION BY "Provider CCN"
                        ORDER BY TO_DATE("Fiscal Year End Date", 'MM/DD/YYYY') DESC
                    ) AS rn
                FROM raw.cost_report cr
            ) cr
            WHERE rn = 1
        """))
        count = conn.execute(text("SELECT COUNT(*) FROM staging.cost_report_dedup")).scalar()

    print(f"Rows after dedup: {count}")


if __name__ == "__main__":
    main()
