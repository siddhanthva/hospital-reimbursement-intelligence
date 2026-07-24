-- Grain: one row per hospital x DRG.
--
-- derived_cost = charges x cost-to-charge ratio (CCR is reported per
-- hospital, not per DRG -- CMS doesn't publish DRG-level cost).
-- margin = Medicare payment - derived_cost. Uses avg_medicare_payment_amount
-- (the Medicare-only payment), not avg_total_payment_amount (which also
-- includes coinsurance/deductible and other-payer amounts) -- confirmed
-- avg_medicare_payment_amount <= avg_total_payment_amount on every row in
-- fct_medicare_drg, consistent with CMS's field definitions.
--
-- Hospitals with no usable CCR are excluded (can't derive cost without one),
-- per the Day 6 pre-flight check: 32/3,075 hospitals in fct_hospital_finance
-- have NULL cost_to_charge_ratio (documented in fct_hospital_finance's
-- schema test). Of those, only 13 actually bill Medicare DRGs at all, plus
-- 6 more hospitals that bill DRGs but have no cost report row whatsoever --
-- 19 hospitals / 140 of 145,604 DRG-fact rows (~0.1%) dropped here. Excluded
-- rather than imputed: simple, transparent, doesn't invent cost data.
--
-- Also excludes is_ccr_outlier = true hospitals (found by reading Step 14's
-- output, not by assumption: the initial version of this model put Gallup
-- Indian Medical Center's service lines at -$2M avg_margin, ~80x worse than
-- the next worst row, because its CCR of 71.3 -- already flagged in Day 5 as
-- a CMS reporting/units error, not a real cost-to-charge ratio -- got
-- multiplied straight into derived_cost. 12 rows across the outlier
-- hospitals dropped here; the raw figures are untouched everywhere upstream,
-- this mart just doesn't let a known-bad CCR drive a "which service line
-- loses the most money" ranking.
with drg_fact as (

    select *
    from {{ ref('fct_medicare_drg') }}

),

finance as (

    select *
    from {{ ref('fct_hospital_finance') }}
    where cost_to_charge_ratio is not null
      and is_ccr_outlier = false

),

hospital as (

    select *
    from {{ ref('dim_hospital') }}

),

drg as (

    select *
    from {{ ref('dim_drg') }}

),

geography as (

    select *
    from {{ ref('dim_geography') }}

)

select
    d.hospital_key,
    d.drg_key,
    h.hospital_name,
    h.cbsa_code,
    g.metro_name,
    dg.drg_code,
    dg.drg_description,
    dg.service_line,
    d.total_discharges,
    d.avg_submitted_covered_charge as charges,
    d.avg_medicare_payment_amount as medicare_payment,
    f.cost_to_charge_ratio,
    d.avg_submitted_covered_charge * f.cost_to_charge_ratio as derived_cost,
    d.avg_medicare_payment_amount
        - (d.avg_submitted_covered_charge * f.cost_to_charge_ratio) as margin
from drg_fact d
inner join finance f on d.hospital_key = f.hospital_key
inner join hospital h on d.hospital_key = h.hospital_key
inner join drg dg on d.drg_key = dg.drg_key
left join geography g on h.cbsa_code = g.cbsa_code
