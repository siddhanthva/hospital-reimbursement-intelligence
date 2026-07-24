-- Grain: one row per service_line x metro (metro_name is NULL for the ~140
-- hospitals outside any CBSA -- kept as its own "non-metro" group rather
-- than dropped).
--
-- avg_margin is an unweighted mean of margin across the hospital x DRG rows
-- in mart_reimbursement_gap -- each DRG counts once, regardless of discharge
-- volume. total_discharge_volume is tracked alongside it precisely so a
-- service line with a large average margin on tiny volume doesn't get
-- mistaken for a big financial driver.
--
-- Volume threshold: real distribution of total_discharge_volume across the
-- 5,946 service_line x metro groups has p5=13, p25=54, median=180. Groups
-- under 30 discharges (~15% of groups) are excluded from ranking as noise --
-- e.g. a service line with 3 discharges and one bad debt can swing avg_margin
-- wildly without representing a real pattern. They stay in the mart with a
-- NULL rank rather than being dropped, so no data disappears silently.
with gap as (

    select *
    from {{ ref('mart_reimbursement_gap') }}

),

agg as (

    select
        service_line,
        metro_name,
        avg(margin) as avg_margin,
        sum(medicare_payment) as total_medicare_payment,
        sum(derived_cost) as total_derived_cost,
        sum(total_discharges) as total_discharge_volume
    from gap
    group by 1, 2

),

qualifying as (

    select *
    from agg
    where total_discharge_volume >= 30

),

ranked as (

    select
        service_line,
        metro_name,
        rank() over (order by avg_margin asc) as global_rank,
        rank() over (partition by metro_name order by avg_margin asc) as metro_rank
    from qualifying

)

select
    {{ dbt_utils.generate_surrogate_key(['a.service_line', 'a.metro_name']) }} as service_line_margin_key,
    a.service_line,
    a.metro_name,
    a.avg_margin,
    a.total_medicare_payment,
    a.total_derived_cost,
    a.total_discharge_volume,
    a.total_discharge_volume >= 30 as meets_volume_threshold,
    r.global_rank,
    r.metro_rank
from agg a
left join ranked r
    on a.service_line = r.service_line
    and a.metro_name is not distinct from r.metro_name
