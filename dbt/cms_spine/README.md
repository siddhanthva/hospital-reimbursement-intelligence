Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test


### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices

### Data quality notes

**Hospital identity disagrees across federal sources.** `hospital_general_info`,
`cost_report`, and `medicare_inpatient` each carry their own name/address/city/
state/zip for the same CCN, and they don't agree:
- Hospital name: 56% mismatch between `cost_report` and `hospital_general_info`
- ZIP code: 42% mismatch between the same two sources
- Hospital name: 14% mismatch between `medicare_inpatient` and `hospital_general_info`

`dim_hospital` standardizes on `hospital_general_info` (CMS Care Compare) as the
authoritative source for hospital identity/location. The duplicate fields were
dropped from `stg_cost_report` and `stg_medicare_inpatient` during cleaning.

**Two CBSA (metro area) fields, and they disagree 42% of the time.** The
HUD ZIP-CBSA crosswalk gives each hospital's physical-geography CBSA;
`cost_report`'s own `medicare_cbsa` is CMS's payment geography, which can
differ due to wage-index reclassification (hospitals can reclassify to a
different area's wage index under Medicare's rules). On the 2,935 hospitals
where both are populated, 1,244 (42%) disagree.

Decision: `dim_hospital.cbsa_code` (HUD-crosswalk-derived) is the CBSA key
used for demographic joins (`dim_geography`), since Census reports by
physical CBSA. `cost_report`'s field is kept as `dim_hospital.medicare_payment_cbsa`,
an attribute, not a join key. `dim_hospital.is_cbsa_reclassified` flags where
the two disagree (NULL when either side is missing, not false -- we can't
confirm "not reclassified" without both values).

### Test suite (Day 5)

`dbt build` runs 39 data tests: not_null/unique on every staging and mart key,
grain-lock tests (`unique_combination_of_columns`) on `stg_medicare_inpatient`
and `fct_medicare_drg`, `accepted_values` on `dim_drg.service_line`, and
`relationships` tests proving every fact row's `hospital_key`/`drg_key`
resolves in its dimension.

All unique/not_null tests on dims pass cleanly and both `relationships`
tests pass -- confirming the Day 4 joins didn't fan out (the CBSA crosswalk
and RUCA joins were deduped/grain-checked before being wired in) and neither
fact table has an orphaned foreign key (both facts use INNER JOIN to their
dims, so this holds by construction, but the tests catch it if that ever
changes).

Two tests are `severity: warn` by design, not loosened to pass. Both were
checked against `raw.cost_report` directly (not just the staged/fact
output) to rule out a bug in our pipeline -- `cost_to_charge_ratio` is a
straight rename of CMS's own `"Cost To Charge Ratio"` field with no
arithmetic on our side, so there is no "our formula" to have a divide-by-
zero or wrong-denominator bug in. Both conditions originate entirely in
CMS's source data.

- **`not_null` on `fct_hospital_finance.cost_to_charge_ratio`** (32/3,075,
  1%): not random. `ownership_type = 7` is only 26/3,075 hospitals overall
  (0.85%) but is 25/32 (78%) of the null rows -- a ~90x over-representation.
  These also skew rural (19/32), cluster in AZ/OK/NM/PR/SD/AK/MT/ND, and
  average 42 beds vs. 205 overall. In raw `cost_report`, `Cost To Charge
  Ratio` is blank even on rows where `Total Costs`/`Total Charges` are both
  populated (not a divide-by-zero) -- combined with names like Gallup
  Indian Medical Center, this points to federal/tribal (Indian Health
  Service) facilities, which don't bill fee-for-service the same way and
  likely fall outside CMS's standard CCR methodology. Two rows (`400010`,
  `400134`) have every financial field null -- genuinely incomplete
  filings, unrelated to the ownership_type=7 pattern.
- **`assert_ccr_between_0_and_1`** (12/3,075 hospitals, 0.4%): unlike the
  nulls, this group has no clustering by ownership_type, rural_urban, or
  provider_type -- scattered, idiosyncratic anomalies rather than a
  systemic category issue. The 3 most extreme (61x-3,110x: Commonwealth
  Health Center, Gallup Indian Medical Center, Whitfield Medical Surgical
  Hospital) have implausibly tiny `Total Charges` relative to their cost
  base, almost certainly a CMS reporting/units error (the same bad
  `Total Charges` value also feeds other fields in that row, so nulling
  just the ratio wouldn't fix the underlying problem). The remaining ~9,
  mostly 1.02-2x (e.g. Kaiser Permanente Central Hospital), are plausibly
  legitimate: integrated/managed-care hospitals that don't bill
  fee-for-service can genuinely report charges below cost.

### Business marts (Day 6)

`mart_reimbursement_gap` (grain: hospital x DRG) derives `margin` =
`medicare_payment - (charges x cost_to_charge_ratio)`, joining in
hospital/metro/service-line descriptive fields so downstream tools need one
table, not four. `mart_service_line_margin` rolls that up to service_line x
metro with `avg_margin`, totals, and two `RANK()` columns (global and
per-metro), scoped to groups with >= 30 total discharges to keep low-volume
noise out of the rankings (below-threshold groups keep their row with a NULL
rank, not dropped).

Both marts exclude hospitals with NULL `cost_to_charge_ratio` **and**
`is_ccr_outlier = true` -- the first pass only filtered NULLs and put Gallup
Indian Medical Center's service lines at ~80x worse than anything else in
the country, because its already-flagged CCR of 71.3 (a CMS reporting
error, not a real ratio) got multiplied straight through. Full writeup and
the resulting business findings are in
[`notebooks/day6_findings.md`](../../notebooks/day6_findings.md).

### Finance scorecard marts (Day 7)

`mart_finance_scorecard` (grain: one row per hospital, from
`fct_hospital_finance` + `dim_hospital` + `dim_geography`) computes
`charity_pct_of_revenue` and `uncompensated_pct_of_revenue` against
`net_patient_revenue` -- checked against raw `cost_report` first rather than
guessing: `Total Patient Revenue` is gross/pre-discount (avg ~$978M, ~5x avg
`Total Costs`), while `Net Patient Revenue` (= Total Patient Revenue minus
Contractual Allowance, verified exact) tracks Total Costs at a comparable
scale (avg ~$238M vs ~$193M) -- the one that's actually usable as a
denominator. 5 of 3,075 hospitals have non-positive `net_patient_revenue`
(one at -$3.1B against $803M total costs, clearly an upstream reporting
error); both ratio columns are NULL for those 5 rather than a nonsensical
negative or divide-by-zero percentage.

Spot-checked the resulting percentages: the highest `charity_pct_of_revenue`
values are Harris Health, Parkland, JPS Health Network, Provident Hospital
of Chicago, Metro Nashville General -- all well-known public safety-net
hospital systems. That's a real pattern (safety-net hospitals absorb far
more charity care than the median hospital), not a denominator bug, which is
exactly the kind of "does this make sense" check Day 7 asks for before
trusting a new ratio.

`mart_burden_vs_community` (same hospital grain, not pre-aggregated -- feeds
Day 8's correlation work and Day 11's scatter plot) left-joins
`mart_finance_scorecard` to `dim_geography` on CBSA for `uninsured_rate` and
`median_household_income`. 138 hospitals have no CBSA (rural) and so have
NULL community fields; left-joined rather than dropped so they aren't
silently removed from the mart. Gut-check: the highest-`uninsured_rate`
metros are the Texas border region (McAllen, Laredo, Brownsville, Rio Grande
City -- a real, well-documented high-uninsured area), with visibly elevated
`uncompensated_pct_of_revenue` there, and `corr(uninsured_rate,
uncompensated_pct_of_revenue) = +0.37` across 2,831 hospitals -- positive
and modest, not flipped or ~0. Full statistical treatment is Day 8's job,
not today's.

### Documentation and lineage

`dbt docs generate` builds `target/catalog.json` / `target/manifest.json`;
`dbt docs serve` renders those into the interactive docs site + DAG. This
session has no browser to click through that UI, so `docs/lineage_graph.png`
was generated instead by `docs/generate_lineage.py`, a one-off script that
parses `depends_on` edges straight out of `manifest.json` (test nodes
excluded) and lays them out sources -> staging/seeds -> dims/facts. Same
underlying dependency data as the interactive graph, just rendered
statically instead of screenshotted.

Spot-checked one model's docs against the plan's checklist
(`fct_medicare_drg`, via manifest/catalog rather than the UI):
- **Description**: "Grain is hospital x DRG."
- **Parents**: `stg_medicare_inpatient`, `dim_hospital`, `dim_drg` -- matches the joins in the model SQL.
- **Children**: none (leaf fact table); the 5 test nodes attached to it show up as children too.
- **Columns**: present with types, but no column-level descriptions yet on this model (only `fct_hospital_finance.cost_to_charge_ratio`/`is_ccr_outlier` have them so far) -- expected at this stage, per the plan.

Decision for both: flag, don't exclude or cap. `fct_hospital_finance.is_ccr_outlier`
marks the 12 range violations so downstream queries can choose to exclude
them, but the raw reported figures stay intact for both groups. Warn
severity keeps the counts visible on every build without blocking the
pipeline on a known, already-investigated condition. For the Day 12 memo:
worth a line noting ~1% of hospitals (concentrated in federal/tribal
facilities) are excluded from CCR-dependent margin analysis due to
incomplete cost report data, and that a small number of CCR values are
known source anomalies rather than corrected/estimated figures.
