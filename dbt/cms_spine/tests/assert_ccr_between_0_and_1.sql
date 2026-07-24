-- Cost-to-charge ratio should be between 0 and 1 for the vast majority of
-- hospitals (costs generally shouldn't exceed billed charges). Nulls are
-- covered separately by the not_null test on this column, not here.
--
-- severity: warn is deliberate, not a loosened threshold -- the 12 rows
-- this catches were investigated (see fct_hospital_finance.is_ccr_outlier
-- and the README) and are either upstream CMS reporting errors we can't
-- correct, or plausible non-fee-for-service billing. Warn keeps every
-- build reporting the count without blocking on a known condition; if the
-- count changes on a future refresh, that's worth investigating again.
{{ config(severity = 'warn') }}

select *
from {{ ref('fct_hospital_finance') }}
where cost_to_charge_ratio is not null
  and (cost_to_charge_ratio < 0 or cost_to_charge_ratio > 1)
