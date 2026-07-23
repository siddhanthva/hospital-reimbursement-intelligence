-- Grain: one row per hospital x DRG. No date foreign key: the raw
-- medicare_inpatient source has no date/year column at all (it's a
-- single-period CMS public use file), so there's nothing to join dim_date on.
with medicare_inpatient as (

    select *
    from {{ ref('stg_medicare_inpatient') }}

),

hospitals as (

    select ccn, hospital_key
    from {{ ref('dim_hospital') }}

),

drgs as (

    select drg_code, drg_key
    from {{ ref('dim_drg') }}

)

select
    h.hospital_key,
    d.drg_key,
    m.total_discharges,
    m.avg_submitted_covered_charge,
    m.avg_total_payment_amount,
    m.avg_medicare_payment_amount
from medicare_inpatient m
inner join hospitals h on m.ccn = h.ccn
inner join drgs d on m.drg_code = d.drg_code
