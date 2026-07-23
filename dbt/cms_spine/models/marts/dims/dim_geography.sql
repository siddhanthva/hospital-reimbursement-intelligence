with source as (

    select *
    from {{ ref('stg_census_acs') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['cbsa_code']) }} as geography_key,
    cbsa_code,
    name                     as metro_name,
    median_household_income,
    total_population,
    median_age,
    insurance_universe,
    uninsured_count,
    uninsured_rate
from source
