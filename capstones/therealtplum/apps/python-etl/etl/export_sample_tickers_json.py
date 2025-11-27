import os
import sys
import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional

import psycopg2
import psycopg2.extras

# -------------------------------------------------------------------
# Config
# -------------------------------------------------------------------

DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

# How many instruments to export from the latest focus snapshot
SAMPLE_TICKERS_LIMIT = int(os.getenv("SAMPLE_TICKERS_LIMIT", "25"))

# Which insight types to treat as "short" and "recent"
SAMPLE_TICKERS_SHORT_KIND = os.getenv("SAMPLE_TICKERS_SHORT_KIND", "overview")
SAMPLE_TICKERS_RECENT_KIND = os.getenv("SAMPLE_TICKERS_RECENT_KIND", "recent")

# Where to write the JSON file
# Default: apps/web/data/sample_tickers.json (relative to this file)
DEFAULT_OUTPUT_PATH = (
    Path(__file__).resolve().parents[2]  # .../apps
    / "web"
    / "data"
    / "sample_tickers.json"
)
OUTPUT_PATH = Path(os.getenv("SAMPLE_TICKERS_OUTPUT_PATH", str(DEFAULT_OUTPUT_PATH)))

logging.basicConfig(
    level=logging.INFO,
    format="[export_sample_tickers] %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger(__name__)


# -------------------------------------------------------------------
# DB helpers
# -------------------------------------------------------------------

def get_conn():
    return psycopg2.connect(DATABASE_URL)


# -------------------------------------------------------------------
# Core query
# -------------------------------------------------------------------

def fetch_sample_tickers(conn) -> List[Dict[str, Any]]:
    """
    Pull the top N focus instruments from the latest instrument_focus_universe snapshot,
    join in instruments + latest insights, and compute prior-day close from the most
    recent earlier focus snapshot for each instrument.
    """
    query = """
    WITH latest_date AS (
        SELECT MAX(as_of_date) AS as_of_date
        FROM instrument_focus_universe
    ),
    -- Focus rows for the latest snapshot
    focus_latest AS (
        SELECT fu.*
        FROM instrument_focus_universe fu
        JOIN latest_date ld
          ON fu.as_of_date = ld.as_of_date
    ),
    -- All focus rows prior to the latest snapshot
    prior_focus AS (
        SELECT fu.*
        FROM instrument_focus_universe fu
        JOIN latest_date ld
          ON fu.as_of_date < ld.as_of_date
    ),
    -- For each instrument, find the most recent prior focus row
    ranked_prior AS (
        SELECT
            instrument_id,
            last_close_price,
            ROW_NUMBER() OVER (
                PARTITION BY instrument_id
                ORDER BY as_of_date DESC
            ) AS rn
        FROM prior_focus
    ),
    prior_prices AS (
        SELECT
            instrument_id,
            last_close_price AS prior_day_last_close_price
        FROM ranked_prior
        WHERE rn = 1
    ),
    -- Latest "short" (overview) insights per instrument
    short_insights AS (
        SELECT DISTINCT ON (instrument_id)
            instrument_id,
            content_markdown AS short_insight
        FROM instrument_insights
        WHERE insight_type = %s
        ORDER BY instrument_id, created_at DESC
    ),
    -- Latest "recent" insights per instrument
    recent_insights AS (
        SELECT DISTINCT ON (instrument_id)
            instrument_id,
            content_markdown AS recent_insight
        FROM instrument_insights
        WHERE insight_type = %s
        ORDER BY instrument_id, created_at DESC
    )
    SELECT
        i.id AS instrument_id,
        i.ticker,
        i.name,
        focus.asset_class::text AS asset_class,
        focus.last_close_price::text AS last_close_price,
        prior.prior_day_last_close_price::text AS prior_day_last_close_price,
        si.short_insight,
        ri.recent_insight
    FROM focus_latest AS focus
    JOIN instruments i
      ON i.id = focus.instrument_id
    LEFT JOIN prior_prices prior
      ON prior.instrument_id = focus.instrument_id
    LEFT JOIN short_insights si
      ON si.instrument_id = focus.instrument_id
    LEFT JOIN recent_insights ri
      ON ri.instrument_id = focus.instrument_id
    ORDER BY focus.activity_rank_global ASC
    LIMIT %s;
    """

    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute(
            query,
            (
                SAMPLE_TICKERS_SHORT_KIND,
                SAMPLE_TICKERS_RECENT_KIND,
                SAMPLE_TICKERS_LIMIT,
            ),
        )
        rows = cur.fetchall()

    results: List[Dict[str, Any]] = []
    for row in rows:
        results.append(
            {
                "instrument_id": int(row["instrument_id"]),
                "ticker": row["ticker"],
                "name": row["name"],
                "asset_class": row["asset_class"],
                "last_close_price": row["last_close_price"],
                "prior_day_last_close_price": row["prior_day_last_close_price"],
                "short_insight": row["short_insight"],
                "recent_insight": row["recent_insight"],
            }
        )

    return results


# -------------------------------------------------------------------
# Existing file loader (for sticky prior prices)
# -------------------------------------------------------------------

def load_existing_prior_prices(path: Path) -> Dict[int, str]:
    """
    Load prior_day_last_close_price from an existing sample_tickers.json, if present.

    Returns:
        { instrument_id: prior_day_last_close_price (string) }
    """
    if not path.exists():
        return {}

    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        log.warning(f"Failed to read existing sample_tickers.json at {path}: {e}")
        return {}

    mapping: Dict[int, str] = {}
    if not isinstance(data, list):
        return mapping

    for row in data:
        try:
            inst_id = int(row.get("instrument_id"))
        except Exception:
            continue

        prior = row.get("prior_day_last_close_price")
        if prior in (None, "", "null"):
            continue

        mapping[inst_id] = str(prior)

    log.info(f"Loaded prior prices for {len(mapping)} instruments from existing JSON.")
    return mapping


# -------------------------------------------------------------------
# File writer
# -------------------------------------------------------------------

def write_sample_tickers_file(data: List[Dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")

    log.info(f"Writing {len(data)} tickers to temporary file: {tmp_path}")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    tmp_path.replace(path)
    log.info(f"Wrote sample tickers JSON to: {path}")


# -------------------------------------------------------------------
# CLI entrypoint
# -------------------------------------------------------------------

def main():
    log.info(
        f"Starting export of sample tickers "
        f"(limit={SAMPLE_TICKERS_LIMIT}, "
        f"short_kind={SAMPLE_TICKERS_SHORT_KIND}, "
        f"recent_kind={SAMPLE_TICKERS_RECENT_KIND})"
    )

    # Load existing prior prices (if any) before we overwrite the file
    existing_prior = load_existing_prior_prices(OUTPUT_PATH)

    conn = get_conn()
    try:
        sample_tickers = fetch_sample_tickers(conn)
        if not sample_tickers:
            log.warning("No sample tickers returned from DB; not writing file.")
            return

        log.info(f"Fetched {len(sample_tickers)} sample tickers from DB.")

        # Apply sticky prior-close logic
        for row in sample_tickers:
            inst_id = int(row["instrument_id"])
            prior = row.get("prior_day_last_close_price")

            # If DB didn't give us a prior, and we have one from the old file, reuse it
            if prior in (None, "None"):
                reused = existing_prior.get(inst_id)
                if reused is not None:
                    row["prior_day_last_close_price"] = reused
                else:
                    # As a last resort, fall back to last_close_price so it's never null
                    row["prior_day_last_close_price"] = row.get("last_close_price")

        write_sample_tickers_file(sample_tickers, OUTPUT_PATH)
    finally:
        conn.close()
        log.info("DB connection closed.")


if __name__ == "__main__":
    main()