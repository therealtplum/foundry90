import os
import logging
import psycopg2
from psycopg2.extras import execute_values

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

logging.basicConfig(
    level=logging.INFO,
    format="[instrument_focus_universe] %(message)s",
)
log = logging.getLogger(__name__)


TOP_N_GLOBAL = int(os.getenv("FOCUS_UNIVERSE_TOP_N", "500"))


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def get_latest_price_date(cur) -> str | None:
    """
    Find the most recent price_date in instrument_price_daily that has
    a reasonable number of instruments (at least 1000) to ensure we're
    using a full trading day rather than a partial day.
    Returns a date string (YYYY-MM-DD) or None if table is empty.
    """
    cur.execute("""
        SELECT price_date
        FROM instrument_price_daily
        WHERE data_source = 'polygon_prev'
        GROUP BY price_date
        HAVING COUNT(DISTINCT instrument_id) >= 1000
        ORDER BY price_date DESC
        LIMIT 1;
    """)
    row = cur.fetchone()
    return row[0] if row and row[0] is not None else None


def compute_focus_universe(cur, as_of_date: str):
    """
    For a given as_of_date (matching price_date), compute the focus universe
    using instruments_useq as the base universe.

    - dollar_volume = close * volume
    - activity_rank_global: rank by dollar_volume desc
    - activity_rank_asset_class: rank by dollar_volume desc within asset_class
    """
    log.info(f"Computing focus universe for as_of_date={as_of_date} (TOP_N_GLOBAL={TOP_N_GLOBAL})")

    # Use a CTE with window functions to compute ranks in the DB
    cur.execute(
        """
        WITH base AS (
            SELECT
                i.id AS instrument_id,
                i.asset_class,
                p.close AS last_close_price,
                COALESCE(p.volume, 0) AS volume,
                (p.close * COALESCE(p.volume, 0))::NUMERIC(30, 4) AS dollar_volume
            FROM instrument_price_daily p
            JOIN instruments_useq i
              ON i.id = p.instrument_id
            WHERE p.price_date = %s
              AND p.data_source = 'polygon_prev'
        ),
        ranked AS (
            SELECT
                instrument_id,
                asset_class,
                last_close_price,
                volume,
                dollar_volume,
                RANK() OVER (ORDER BY dollar_volume DESC) AS activity_rank_global,
                RANK() OVER (PARTITION BY asset_class ORDER BY dollar_volume DESC) AS activity_rank_asset_class
            FROM base
        )
        SELECT
            instrument_id,
            asset_class,
            last_close_price,
            volume,
            dollar_volume,
            activity_rank_global,
            activity_rank_asset_class
        FROM ranked
        WHERE activity_rank_global <= %s
        ORDER BY activity_rank_global ASC;
        """,
        (as_of_date, TOP_N_GLOBAL),
    )

    rows = cur.fetchall()
    log.info(f"Computed {len(rows)} focus instruments for {as_of_date}")
    return rows


def replace_focus_universe_for_date(cur, as_of_date: str, rows: list[tuple]):
    """
    Replace all rows in instrument_focus_universe for the given as_of_date
    with the provided dataset.
    """
    log.info(f"Deleting existing focus universe rows for as_of_date={as_of_date}")
    cur.execute(
        "DELETE FROM instrument_focus_universe WHERE as_of_date = %s;",
        (as_of_date,),
    )

    if not rows:
        log.info("No rows to insert after delete; focus universe will be empty for this date.")
        return

    # Prepare rows for bulk insert
    payload = [
        (
            as_of_date,                 # as_of_date
            r[0],                       # instrument_id
            r[1],                       # asset_class
            r[4],                       # dollar_volume
            r[3],                       # volume
            r[5],                       # activity_rank_global
            r[6],                       # activity_rank_asset_class
            r[2],                       # last_close_price
        )
        for r in rows
    ]

    log.info(f"Inserting {len(payload)} rows into instrument_focus_universe for {as_of_date}")

    execute_values(
        cur,
        """
        INSERT INTO instrument_focus_universe (
            as_of_date,
            instrument_id,
            asset_class,
            dollar_volume,
            volume,
            activity_rank_global,
            activity_rank_asset_class,
            last_close_price
        )
        VALUES %s
        """,
        payload,
    )


def main():
    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()

    try:
        as_of_date = get_latest_price_date(cur)
        if as_of_date is None:
            log.warning("instrument_price_daily is empty; nothing to do.")
            conn.rollback()
            return

        log.info(f"Latest price_date in instrument_price_daily is {as_of_date}")

        rows = compute_focus_universe(cur, as_of_date)
        replace_focus_universe_for_date(cur, as_of_date, rows)

        conn.commit()
        log.info(f"Focus universe updated successfully for {as_of_date}")

    except Exception as e:
        log.exception(f"Error computing focus universe: {e}")
        conn.rollback()
        raise

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()