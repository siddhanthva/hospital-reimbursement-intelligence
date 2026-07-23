with source_data as (

    select *
    from {{ source('raw', 'hospital_general_info') }}

),

cleaned as (

    select
        "Facility ID"                                        as facility_id,
        "Facility Name"                                       as facility_name,
        "Address"                                             as address,
        "City/Town"                                           as city,
        "State"                                               as state,
        "ZIP Code"                                            as zip_code,
        upper(replace(trim("County/Parish"), ' ', ''))        as county,
        "Telephone Number"                                    as phone_number,
        "Hospital Ownership"                                   as hospital_ownership,
        "Emergency Services"                                   as emergency_services,
        "Meets criteria for birthing friendly designation"     as birthing_friendly_designation,
        nullif("Hospital overall rating", 'Not Available')::integer as hospital_overall_rating
    from source_data
    where "Hospital Type" = 'Acute Care Hospitals'

)

select *
from cleaned
