"""Build staging.census_uninsured_clean (uninsured_rate by CBSA) from raw.census_acs.

Verified against the actual raw.census_acs columns (not just the project docs):
  universe            -> B27010_001E
  uninsured counts     -> B27010_017E, B27010_033E, B27010_050E, B27010_066E
  cbsa                 -> "metropolitan statistical area/micropolitan statistical area"
"""

import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

UNINSURED_COLS = ["B27010_017E", "B27010_033E", "B27010_050E", "B27010_066E"]
UNIVERSE_COL = "B27010_001E"
CBSA_COL = "metropolitan statistical area/micropolitan statistical area"


def main():
    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    uninsured_sum = " + ".join(f'"{c}"' for c in UNINSURED_COLS)

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))
        conn.execute(text("DROP TABLE IF EXISTS staging.census_uninsured_clean"))
        conn.execute(text(f"""
            CREATE TABLE staging.census_uninsured_clean AS
            SELECT
                "NAME" AS name,
                "{CBSA_COL}" AS cbsa,
                "{UNIVERSE_COL}" AS universe,
                ({uninsured_sum}) AS uninsured_count,
                ({uninsured_sum})::numeric / "{UNIVERSE_COL}" AS uninsured_rate
            FROM raw.census_acs
        """))
        count = conn.execute(text("SELECT COUNT(*) FROM staging.census_uninsured_clean")).scalar()

    print(f"Census rows: {count}")


if __name__ == "__main__":
    main()
