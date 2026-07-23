with source_data as (

    select *
    from {{ source('raw', 'zip_cbsa_crosswalk') }}

),

cleaned as (

    select
        geoid                as zip_code,
        cbsa                 as cbsa_code,
        res_ratio
    from source_data
    where cbsa <> '99999'

)

select *
from cleaned
