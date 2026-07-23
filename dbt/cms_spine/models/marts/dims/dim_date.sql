-- Spans the fiscal_year_begin_date/fiscal_year_end_date range found in
-- stg_cost_report (2022-10-01 through 2024-09-30). medicare_inpatient has
-- no date column in the raw source, so it has no dim_date foreign key.
with spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2022-10-01' as date)",
        end_date="cast('2024-10-01' as date)"
    ) }}

),

renamed as (

    select
        date_day::date                       as date_day,
        extract(year from date_day)::integer    as calendar_year,
        extract(quarter from date_day)::integer as calendar_quarter,
        extract(month from date_day)::integer   as calendar_month,
        trim(to_char(date_day, 'Month'))        as month_name,
        extract(day from date_day)::integer     as day_of_month,
        extract(dow from date_day)::integer     as day_of_week,
        trim(to_char(date_day, 'Day'))           as day_name
    from spine

)

select
    to_char(date_day, 'YYYYMMDD')::integer as date_key,
    *
from renamed
