"use client";

import { useEffect, useMemo, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

// If this env var is NOT set to "true", we never call the live API.
// On Vercel, this will default to false → always use fallback data.
const USE_LIVE_API = process.env.NEXT_PUBLIC_USE_LIVE_API === "true";

// A small, static snapshot of the focus universe so Vercel
// can always render something, even with no backend running.
const FALLBACK_TICKERS: FocusTickerStripItem[] = [
  {
    instrument_id: 32892,
    ticker: "NVDA",
    name: "Nvidia Corp",
    asset_class: "equity",
    last_close_price: "182.55",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 38771,
    ticker: "SPY",
    name: "SPDR S&P 500 ETF Trust",
    asset_class: "equity",
    last_close_price: "668.73",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 35489,
    ticker: "QQQ",
    name: "Invesco QQQ Trust, Series 1",
    asset_class: "equity",
    last_close_price: "605.16",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 40741,
    ticker: "TSLA",
    name: "Tesla, Inc.",
    asset_class: "equity",
    last_close_price: "417.78",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 12309,
    ticker: "GOOGL",
    name: "Alphabet Inc. Class A",
    asset_class: "equity",
    last_close_price: "318.58",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 12308,
    ticker: "GOOG",
    name: "Alphabet Inc. Class C",
    asset_class: "equity",
    last_close_price: "318.47",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 1334,
    ticker: "AMD",
    name: "Advanced Micro Devices",
    asset_class: "equity",
    last_close_price: "215.05",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 30416,
    ticker: "META",
    name: "Meta Platforms, Inc. Class A",
    asset_class: "equity",
    last_close_price: "613.05",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 2430,
    ticker: "AVGO",
    name: "Broadcom Inc.",
    asset_class: "equity",
    last_close_price: "377.96",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 56,
    ticker: "AAPL",
    name: "Apple Inc.",
    asset_class: "equity",
    last_close_price: "275.92",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 999001,
    ticker: "IBIT",
    name: "iShares Bitcoin Trust ETF",
    asset_class: "equity",
    last_close_price: "50.57",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 999002,
    ticker: "MSTR",
    name: "MicroStrategy Inc. Class A",
    asset_class: "equity",
    last_close_price: "179.04",
    short_insight: null,
    recent_insight: null,
  },
];

const ROW_COUNT = 6;

function formatPrice(value: string | null): string {
  if (!value) return "--";
  const num = Number(value);
  if (!Number.isFinite(num)) return value;
  return `$${num.toFixed(2)}`;
}

export default function TickerBoard() {
  const [items, setItems] = useState<FocusTickerStripItem[]>(FALLBACK_TICKERS);

  // Try to hydrate with real data ONLY if the env flag is on.
  useEffect(() => {
    if (!USE_LIVE_API) return;

    let cancelled = false;

    async function load() {
      try {
        const live = await getFocusTickerStrip(96);
        if (!cancelled && live && live.length > 0) {
          setItems(live);
        }
      } catch (err) {
        console.error("[TickerBoard] Live API failed, staying on fallback:", err);
      }
    }

    load();

    return () => {
      cancelled = true;
    };
  }, []);

  // Split tickers into rows, and only use as many as we need to fill the screen.
  const rows = useMemo(() => {
    const limited = items.slice(0, ROW_COUNT * 8); // ~8 per row
    const buckets: FocusTickerStripItem[][] = Array.from(
      { length: ROW_COUNT },
      () => [],
    );

    limited.forEach((item, idx) => {
      buckets[idx % ROW_COUNT].push(item);
    });

    return buckets;
  }, [items]);

  return (
    <div className="f90-board-shell">
      <div className="f90-board">
        <div className="f90-board-inner">
          {rows.map((row, rowIndex) => {
            // If this row ended up empty (very small dataset), just reuse the whole list
            const effectiveRow = row.length > 0 ? row : items;

            return (
              <div
                key={rowIndex}
                className={`f90-row ${
                  rowIndex % 2 === 0 ? "f90-row-left" : "f90-row-right"
                }`}
              >
                {/* duplicate for seamless looping */}
                {[...effectiveRow, ...effectiveRow].map((item, idx) => (
                  <span key={`${item.instrument_id}-${idx}`} className="f90-chip">
                    <span className="f90-chip-symbol">{item.ticker}</span>
                    <span className="f90-chip-name">{item.name}</span>
                    <span className="f90-chip-price">
                      {formatPrice(item.last_close_price)}
                    </span>
                  </span>
                ))}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}