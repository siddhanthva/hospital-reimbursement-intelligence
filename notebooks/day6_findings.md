# Day 6 findings: `mart_reimbursement_gap` / `mart_service_line_margin`

## Question

Which hospital service lines lose the most money treating Medicare patients?

## Method

`margin = medicare_payment - (charges x cost_to_charge_ratio)` per hospital x
DRG, rolled up to service_line x metro. `avg_margin` is an unweighted mean
across DRGs in the group (not discharge-weighted); `total_discharge_volume`
is tracked alongside it so low-volume noise is visible, not hidden. Groups
under 30 total discharges are excluded from ranking (see model SQL comment)
-- 875 of 5,946 groups (~15%).

## Sanity check that changed the model

The first pass ranked **Pulmonology/Respiratory** and **General Medicine** in
Gallup, NM as the two worst service lines in the country by roughly 80x --
avg_margin around -$2,000,000 versus the next-worst row at -$25,000. Traced
it to Gallup Indian Medical Center, which already carries a documented
`is_ccr_outlier = true` flag from Day 5 (CCR of 71.3, a CMS reporting/units
error, not a real cost-to-charge ratio). The original filter only excluded
NULL CCR, not flagged outliers -- fixed by also excluding `is_ccr_outlier =
true` hospitals (12 rows dropped). This is the exact "does this make sense"
check the plan calls for, and it did catch a real bug in the first cut.

## Top 5 worst service lines (global, min. 30 discharges)

| Rank | Service Line | Metro | Avg Margin | Discharges |
|---|---|---|---|---|
| 1 | Oncology | Minneapolis-St. Paul-Bloomington, MN-WI | -$25,166 | 171 |
| 2 | Oncology | Omaha, NE-IA | -$24,148 | 201 |
| 3 | Oncology | Ann Arbor, MI | -$23,508 | 183 |
| 4 | Obstetrics | San Jose-Sunnyvale-Santa Clara, CA | -$22,934 | 39 |
| 5 | General Surgery | San Jose-Sunnyvale-Santa Clara, CA | -$21,402 | 413 |

**Reason (row 1, Minneapolis Oncology):** driven almost entirely by one
hospital, M Health Fairview University of MN Medical Center, on high-cost
cellular/immunotherapy DRGs -- CAR-T (chimeric antigen receptor) therapy at
-$111k/case and allogeneic bone marrow transplant at -$36k/case are the two
biggest line items. This matches well-documented reality: CAR-T and
transplant therapies are notoriously under-reimbursed by Medicare relative
to their billed cost, so this isn't a data artifact, it's a real and
recognizable pattern.

## Top 5 best service lines (global)

Oncology also occupies **all 5** of the best-margin rows (Richmond VA
+$103k down to Cleveland OH +$40k). Oncology has the fewest metro groups of
any service line (131, vs. 400k+ combined groups for the high-volume lines)
and by far the widest spread -- a handful of high-cost, low-volume specialty
DRGs (transplant/immunotherapy vs. routine chemo/infusion) push it to both
extremes depending on hospital case mix. Not a contradiction: it's a
high-variance line, not a uniformly good or bad one.

## Interesting observations

- **48% of ranked groups (2,440 / 5,065) have a negative avg_margin.**
  Consistent with the well-known MedPAC finding that hospitals' *aggregate*
  Medicare margins run negative nationally -- a plausible macro pattern, not
  a modeling error.
- **Estimated portfolio-wide dollar gap: -$1.96B** (sum of margin x
  discharges across every hospital x DRG row). A rough, directional figure
  -- it's built on a single hospital-level CCR applied uniformly across all
  of that hospital's DRGs, not a true DRG-level cost.
- **Metro representation is broad**, not dominated by one region: 780
  distinct metros appear among the 5,065 ranked groups.
- **Volume threshold (30 discharges) is grounded in the actual
  distribution**, not copied blindly: p5=13, p25=54, median=180 discharges
  across all 5,946 groups. 30 sits just below the 25th percentile, cutting
  the noisiest ~15% of groups without discarding a large share of real data.

## Caveat carried from Day 5

`derived_cost` uses one hospital-level CCR applied to every DRG that
hospital bills. CMS doesn't publish DRG-level cost, so this is a standard
simplification in cost-to-charge-ratio-based costing, not unique to this
project -- but it means the CAR-T-therapy-style findings above are more
reliable in relative terms (which service lines are worst) than in absolute
dollar terms (exact size of the loss).
