"""Build staging.hospital_geo by joining hospitals to their CBSA via the HUD ZIP crosswalk.

Some ZIPs span multiple CBSAs, so for each hospital we keep only the
crosswalk row with the largest res_ratio (its dominant CBSA). This is a
LEFT JOIN so hospitals with no crosswalk match are kept (with a NULL cbsa)
rather than silently dropped.
"""

import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text


def main():
    load_dotenv()
    engine = create_engine(os.environ["DATABASE_URL"])

    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))
        conn.execute(text("DROP TABLE IF EXISTS staging.hospital_geo"))
        conn.execute(text("""
            CREATE TABLE staging.hospital_geo AS
            SELECT h.*, best.cbsa, best.res_ratio
            FROM staging.hospital_general_info_clean h
            LEFT JOIN LATERAL (
                SELECT z.cbsa, z.res_ratio
                FROM raw.zip_cbsa_crosswalk z
                WHERE z.geoid = h."ZIP Code"
                ORDER BY z.res_ratio DESC
                LIMIT 1
            ) best ON TRUE
        """))
        count = conn.execute(text("SELECT COUNT(*) FROM staging.hospital_geo")).scalar()
        unmatched = conn.execute(text("SELECT COUNT(*) FROM staging.hospital_geo WHERE cbsa IS NULL")).scalar()

    print(f"Hospital geo rows: {count}")
    print(f"Hospitals with no CBSA match: {unmatched}")


if __name__ == "__main__":
    main()
