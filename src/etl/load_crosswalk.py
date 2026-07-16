"""Load the HUD ZIP-CBSA crosswalk into the `raw` schema of the Postgres database."""

import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
XLSX_PATH = PROJECT_ROOT / "data" / "raw" / "hud_crosswalk" / "CBSA-ZIP_032026.xlsx"

# Column names as they actually appear in this release (verified by opening
# the file directly — HUD has renamed the ZIP column to "geoid" here).
ZIP_COL = "geoid"
CBSA_COL = "cbsa"


def main():
    load_dotenv()
    database_url = os.environ["DATABASE_URL"]
    engine = create_engine(database_url)

    df = pd.read_excel(XLSX_PATH, dtype={ZIP_COL: str, CBSA_COL: str})
    df[ZIP_COL] = df[ZIP_COL].str.strip().str.zfill(5)

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))

    df.to_sql("zip_cbsa_crosswalk", engine, schema="raw", if_exists="replace", index=False)
    print(f"raw.zip_cbsa_crosswalk: loaded {len(df)} rows")


if __name__ == "__main__":
    main()
