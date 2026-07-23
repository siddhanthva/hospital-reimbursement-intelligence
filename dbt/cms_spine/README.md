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
