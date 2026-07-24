-- Grain: one row per hospital.
--
-- Revenue denominator is net_patient_revenue (see stg_cost_report comment):
-- Total Patient Revenue is gross/pre-discount and ~5x Total Costs on
-- average across raw.cost_report -- using it would deflate every ratio to
-- meaninglessly small numbers. Net Patient Revenue tracks Total Costs at a
-- comparable scale and is what CMS's own worksheet defines as revenue after
-- contractual allowances, i.e. what the hospital actually expects to collect.
--
-- 5 of 3,075 hospitals report net_patient_revenue <= 0 (one as extreme as
-- -$3.1B against $803M total_costs -- an upstream reporting error, not a
-- real number). A ratio against a non-positive denominator is undefined, so
-- charity_pct_of_revenue / uncompensated_pct_of_revenue are NULL for those
-- 5 rather than showing a nonsensical negative or divide-by-zero percentage;
-- every other field for those hospitals is left intact.
--
-- "Ownership" uses dim_hospital.hospital_ownership (CMS Care Compare's
-- human-readable category, e.g. "Voluntary non-profit - Private") rather
-- than the cost report's numeric ownership_type code, since this mart is
-- meant to be read directly by non-technical stakeholders.
with finance as (

    select *
    from {{ ref('fct_hospital_finance') }}

),

hospital as (

    select *
    from {{ ref('dim_hospital') }}

),

geography as (

    select *
    from {{ ref('dim_geography') }}

)

select
    f.hospital_key,
    h.hospital_name,
    h.cbsa_code,
    g.metro_name,
    h.hospital_ownership,
    f.net_patient_revenue,
    f.charity_care_cost,
    f.uncompensated_care_cost,
    f.net_income,
    case
        when f.net_patient_revenue > 0
            then f.charity_care_cost / f.net_patient_revenue
    end as charity_pct_of_revenue,
    case
        when f.net_patient_revenue > 0
            then f.uncompensated_care_cost / f.net_patient_revenue
    end as uncompensated_pct_of_revenue
from finance f
inner join hospital h on f.hospital_key = h.hospital_key
left join geography g on h.cbsa_code = g.cbsa_code
