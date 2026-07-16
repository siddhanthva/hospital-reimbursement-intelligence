"""Build staging.hospital_geo by joining hospitals to their CBSA via the HUD ZIP crosswalk.

Some ZIPs span multiple CBSAs, so for each hospital we keep only the
crosswalk row with the largest res_ratio (its dominant CBSA). This is a
LEFT JOIN so hospitals with no crosswalk match are kept (with a NULL
cbsa_code) rather than silently dropped.
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
            SELECT
                h."Facility ID" AS ccn,
                h."Facility Name" AS hospital_name,
                h."Address" AS address,
                h."City/Town" AS city,
                h."State" AS state,
                h."ZIP Code" AS zip_code,
                h."County/Parish" AS county,
                h."Telephone Number" AS telephone_number,
                h."Hospital Type" AS hospital_type,
                h."Hospital Ownership" AS hospital_ownership,
                h."Emergency Services" AS emergency_services,
                h."Meets criteria for birthing friendly designation" AS birthing_friendly_designation,
                h."Hospital overall rating" AS hospital_overall_rating,
                best.cbsa AS cbsa_code,
                best.res_ratio AS res_ratio
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
        unmatched = conn.execute(text("SELECT COUNT(*) FROM staging.hospital_geo WHERE cbsa_code IS NULL")).scalar()

    print(f"Hospital geo rows: {count}")
    print(f"Hospitals with no CBSA match: {unmatched}")


if __name__ == "__main__":
    main()
