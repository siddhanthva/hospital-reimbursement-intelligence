"""Load raw CMS/Census CSVs into the `raw` schema of the Postgres database."""

import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
RAW_DIR = PROJECT_ROOT / "data" / "raw"

# Per-file config: which columns must be read as strings (CCN/CBSA/FIPS/zip
# codes lose leading zeros if parsed as numbers), and which of those are CCN
# columns that need to be zero-padded to 6 characters.
TABLES = [
    {
        "path": RAW_DIR / "medicare_inpatient" / "MUP_INP_RY26_P03_V10_DY24_PrvSvc.CSV",
        "table": "medicare_inpatient",
        "str_columns": ["Rndrng_Prvdr_CCN", "Rndrng_Prvdr_State_FIPS", "Rndrng_Prvdr_Zip5"],
        "ccn_columns": ["Rndrng_Prvdr_CCN"],
    },
    {
        "path": RAW_DIR / "cost_report" / "CostReport_2023_Final.csv",
        "table": "cost_report",
        "str_columns": ["Provider CCN", "Zip Code", "Medicare CBSA Number"],
        "ccn_columns": ["Provider CCN"],
    },
    {
        "path": RAW_DIR / "hospital_general_info" / "Hospital_General_Information.csv",
        "table": "hospital_general_info",
        "str_columns": ["Facility ID", "ZIP Code"],
        "ccn_columns": ["Facility ID"],
    },
    {
        "path": RAW_DIR / "census" / "acs_cbsa_2023.csv",
        "table": "census_acs",
        "str_columns": ["metropolitan statistical area/micropolitan statistical area"],
        "ccn_columns": [],
    },
]


def load_table(engine, config):
    dtype = {col: str for col in config["str_columns"]}
    df = pd.read_csv(config["path"], dtype=dtype)

    for col in config["ccn_columns"]:
        df[col] = df[col].str.strip().str.zfill(6)

    df.to_sql(config["table"], engine, schema="raw", if_exists="replace", index=False)
    print(f"raw.{config['table']}: loaded {len(df)} rows")


def main():
    load_dotenv()
    database_url = os.environ["DATABASE_URL"]
    engine = create_engine(database_url)

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))

    for config in TABLES:
        load_table(engine, config)


if __name__ == "__main__":
    main()
