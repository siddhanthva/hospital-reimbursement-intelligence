with source as (

    select *
    from {{ ref('seed_drg_service_line') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['drg_cd']) }} as drg_key,
    drg_cd as drg_code,
    drg_desc as drg_description,
    service_line
from source
