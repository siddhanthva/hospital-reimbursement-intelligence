"""Clean raw.hospital_general_info into staging.hospital_general_info_clean."""

import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text

SOURCE_TABLE = "hospital_general_info"
COUNTY_COL = "County/Parish"


def main():
    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    inspector = inspect(engine)
    columns = [c["name"] for c in inspector.get_columns(SOURCE_TABLE, schema="raw")]
    select_list = ", ".join(
        f"UPPER(REPLACE(TRIM(\"{c}\"), ' ', '')) AS \"{c}\"" if c == COUNTY_COL else f'"{c}"'
        for c in columns
    )

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))
        conn.execute(text("DROP TABLE IF EXISTS staging.hospital_general_info_clean"))
        conn.execute(text(f"""
            CREATE TABLE staging.hospital_general_info_clean AS
            SELECT {select_list}
            FROM raw.hospital_general_info
            WHERE "Hospital Type" = 'Acute Care Hospitals'
        """))
        count = conn.execute(text("SELECT COUNT(*) FROM staging.hospital_general_info_clean")).scalar()

    print(f"Hospital rows: {count}")


if __name__ == "__main__":
    main()
