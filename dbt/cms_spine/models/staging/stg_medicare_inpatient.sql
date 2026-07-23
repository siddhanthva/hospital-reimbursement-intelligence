with source_data as (

    select *
    from {{ source('raw', 'medicare_inpatient') }}

),

cleaned as (

    select
        "Rndrng_Prvdr_CCN"          as ccn,
        "Rndrng_Prvdr_RUCA"         as ruca_code,
        "Rndrng_Prvdr_RUCA_Desc"    as ruca_description,
        "DRG_Cd"                    as drg_code,
        "DRG_Desc"                  as drg_description,
        "Tot_Dschrgs"                as total_discharges,
        "Avg_Submtd_Cvrd_Chrg"      as avg_submitted_covered_charge,
        "Avg_Tot_Pymt_Amt"          as avg_total_payment_amount,
        "Avg_Mdcr_Pymt_Amt"         as avg_medicare_payment_amount
    from source_data
    where "Tot_Dschrgs" > 0

)

select *
from cleaned
