"""Deduplicate raw.cost_report to one row per CCN (latest fiscal year end) into staging.cost_report_dedup."""

import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text


def main():
    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))
        conn.execute(text("DROP TABLE IF EXISTS staging.cost_report_dedup"))
        conn.execute(text("""
            CREATE TABLE staging.cost_report_dedup AS
            SELECT *
            FROM (
                SELECT
                    cr.*,
                    ROW_NUMBER() OVER (
                        PARTITION BY "Provider CCN"
                        ORDER BY TO_DATE("Fiscal Year End Date", 'MM/DD/YYYY') DESC
                    ) AS rn
                FROM raw.cost_report cr
            ) ranked
            WHERE rn = 1
        """))
        conn.execute(text("ALTER TABLE staging.cost_report_dedup DROP COLUMN rn"))
        count = conn.execute(text("SELECT COUNT(*) FROM staging.cost_report_dedup")).scalar()

    print(f"Rows after dedup: {count}")


if __name__ == "__main__":
    main()
