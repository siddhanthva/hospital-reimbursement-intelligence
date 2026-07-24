-- Grain: one row per hospital (same grain as mart_finance_scorecard --
-- deliberately not pre-aggregated, so this feeds both the Day 11 scatter
-- plot and the Day 8 correlation analysis at full resolution).
--
-- 138 hospitals have no cbsa_code (rural, outside any CBSA -- same set
-- documented in dim_hospital) and so have no uninsured_rate/
-- median_household_income here. Left, not inner, joined: dropping them
-- would silently remove every rural hospital from the burden analysis
-- rather than just leaving its community columns NULL.
with scorecard as (

    select *
    from {{ ref('mart_finance_scorecard') }}

),

geography as (

    select *
    from {{ ref('dim_geography') }}

)

select
    s.hospital_key,
    s.hospital_name,
    s.metro_name,
    s.hospital_ownership,
    s.net_patient_revenue,
    s.charity_pct_of_revenue,
    s.uncompensated_pct_of_revenue,
    g.median_household_income,
    g.uninsured_rate
from scorecard s
left join geography g on s.cbsa_code = g.cbsa_code
