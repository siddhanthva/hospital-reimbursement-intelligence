with hospitals as (

    select *
    from {{ ref('stg_hospital_general_info') }}

),

cost_report as (

    select *
    from {{ ref('stg_cost_report') }}

),

-- Some ZIPs span multiple CBSAs; keep only the crosswalk row with the
-- largest res_ratio (its dominant CBSA) per ZIP.
best_cbsa as (

    select
        zip_code,
        cbsa_code,
        row_number() over (partition by zip_code order by res_ratio desc) as rn
    from {{ ref('stg_zip_cbsa_crosswalk') }}

),

-- RUCA code/description is constant per CCN in stg_medicare_inpatient
-- (verified: 0 CCNs have conflicting values), so this is a safe 1:1 join.
ruca as (

    select distinct
        ccn,
        ruca_code,
        ruca_description
    from {{ ref('stg_medicare_inpatient') }}

),

joined as (

    select
        h.facility_id                      as ccn,
        h.facility_name                    as hospital_name,
        h.address,
        h.city,
        h.state,
        h.zip_code,
        h.county,
        h.phone_number,
        h.hospital_ownership,
        h.emergency_services,
        h.birthing_friendly_designation,
        h.hospital_overall_rating,
        cbsa.cbsa_code,
        cr.ownership_type,
        cr.rural_urban,
        cr.provider_type,
        cr.medicare_payment_cbsa,
        r.ruca_code,
        r.ruca_description
    from hospitals h
    left join best_cbsa cbsa
        on h.zip_code = cbsa.zip_code
        and cbsa.rn = 1
    left join cost_report cr
        on h.facility_id = cr.ccn
    left join ruca r
        on h.facility_id = r.ccn

)

select
    {{ dbt_utils.generate_surrogate_key(['ccn']) }} as hospital_key,
    *,
    -- NULL (not false) when either side is missing -- we can't confirm
    -- "not reclassified" without both values, only "reclassified" or
    -- "unknown". True flags wage-index arbitrage: the hospital's
    -- Medicare payment geography differs from its physical CBSA.
    case
        when medicare_payment_cbsa is not null and cbsa_code is not null
            then medicare_payment_cbsa is distinct from cbsa_code
    end as is_cbsa_reclassified
from joined
