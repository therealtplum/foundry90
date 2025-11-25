"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";
import Link from "next/link";

/**
 * This component is used on the *home dashboard* (not the capstones page)
 * and shows a single scrolling ticker strip.
 *
 * It relies on the live API. If the API is not running (e.g. Vercel build),
 * it shows a simple error message.
 */
export default function FocusTickerStrip() {
  const [tickers, setTickers] = useState<FocusTickerStripItem[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const rows = await getFocusTickerStrip(96);
        if (!cancelled) {
          setTickers(rows);
        }
      } catch (err) {
        console.error("[FocusTickerStrip] Error:", err);
        if (!cancelled) {
          setError("Failed to load focus tickers.");
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  if (error) {
    return (
      <div
        style={{
          marginTop: "20px",
          padding: "12px 0",
          fontSize: "14px",
          opacity: 0.6,
        }}
      >
        {error}
      </div>
    );
  }

  if (!tickers) {
    return (
      <div
        style={{
          marginTop: "20px",
          padding: "12px 0",
          fontSize: "14px",
          opacity: 0.6,
        }}
      >
        Loading tickers…
      </div>
    );
  }

  return (
    <div
      className="f90-ticker-strip"
      style={{
        overflow: "hidden",
        whiteSpace: "nowrap",
        marginTop: "20px",
      }}
    >
      <div className="f90-row-left">
        {tickers.map((item) => (
          <Link
            key={item.instrument_id}
            href={`/instruments/${item.instrument_id}`}
            className="f90-ticker-chip"
            style={{ marginRight: "16px" }}
          >
            <span className="f90-ticker-symbol">{item.ticker}</span>
            <span className="f90-ticker-price">
              {item.last_close_price
                ? `$${Number(item.last_close_price).toFixed(2)}`
                : "--"}
            </span>
          </Link>
        ))}
        {/* duplicate for continuous scroll */}
        {tickers.map((item) => (
          <Link
            key={`dup-${item.instrument_id}`}
            href={`/instruments/${item.instrument_id}`}
            className="f90-ticker-chip"
            style={{ marginRight: "16px" }}
          >
            <span className="f90-ticker-symbol">{item.ticker}</span>
            <span className="f90-ticker-price">
              {item.last_close_price
                ? `$${Number(item.last_close_price).toFixed(2)}`
                : "--"}
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}