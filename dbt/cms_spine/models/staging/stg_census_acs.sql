with source_data as (

    select *
    from {{ source('raw', 'census_acs') }}

),

cleaned as (

    select
        "NAME"                                                          as name,
        "metropolitan statistical area/micropolitan statistical area"   as cbsa_code,
        "B19013_001E"                                                   as median_household_income,
        "B01003_001E"                                                   as total_population,
        "B01002_001E"                                                   as median_age,
        "B27010_001E"                                                   as insurance_universe,
        "B27010_017E" + "B27010_033E" + "B27010_050E" + "B27010_066E"   as uninsured_count
    from source_data
    where "B27010_001E" is not null
      and "B27010_001E" > 0

)

select
    name,
    cbsa_code,
    median_household_income,
    total_population,
    median_age,
    insurance_universe,
    uninsured_count,
    uninsured_count::numeric / insurance_universe as uninsured_rate
from cleaned
