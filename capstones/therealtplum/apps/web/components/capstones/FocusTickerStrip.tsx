// apps/web/components/capstones/FocusTickerStrip.tsx
"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

/**
 * Static fallback focus universe.
 * NOTE: last_close_price is a STRING here to match FocusTickerStripItem.
 */
const STATIC_TICKERS: FocusTickerStripItem[] = [
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
    name: "Tesla, Inc. Common Stock",
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
    instrument_id: 30416,
    ticker: "META",
    name: "Meta Platforms, Inc. Class A",
    asset_class: "equity",
    last_close_price: "613.05",
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
];

/** Try live focus universe; fall back to null on any error. */
async function loadLive(limit = 96): Promise<FocusTickerStripItem[] | null> {
  try {
    const data = await getFocusTickerStrip(limit);
    if (!data || data.length === 0) return null;
    return data;
  } catch (err) {
    console.warn(
      "FocusTickerStrip: live load failed, using static fallback.",
      err,
    );
    return null;
  }
}

function formatPrice(value: string | null): string {
  if (!value) return "";
  const num = Number(value);
  if (!Number.isFinite(num)) return value;
  return num.toFixed(2);
}

export default function FocusTickerStrip() {
  // Start with static data so there is *always* something on screen.
  const [items, setItems] = useState<FocusTickerStripItem[]>(STATIC_TICKERS);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      const live = await loadLive(128);
      if (!cancelled && live) {
        setItems(live);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  // We only need enough to fill the screen nicely.
  const MAX_ITEMS = 64;
  const baseItems = items.slice(0, MAX_ITEMS);

  // Duplicate so each row can scroll seamlessly.
  const loopItems = [...baseItems, ...baseItems];

  const ROWS = 4;
  const perRow = Math.ceil(loopItems.length / ROWS);
  const rowChunks = Array.from({ length: ROWS }, (_, rowIndex) =>
    loopItems.slice(rowIndex * perRow, (rowIndex + 1) * perRow),
  );

  return (
    <div className="f90-capstones-coming">
      {/* scrolling ticker background */}
      <div className="f90-ticker-strip">
        {rowChunks.map((row, rowIndex) => (
          <div
            key={rowIndex}
            className={`f90-ticker-row ${
              rowIndex % 2 === 0
                ? "f90-ticker-row-left"
                : "f90-ticker-row-right"
            }`}
            // Slightly different speeds to keep it organic
            style={{
              animationDuration: rowIndex % 2 === 0 ? "42s" : "54s",
            }}
          >
            {row.map((item, i) => (
              <span key={`${item.instrument_id}-${i}`} className="f90-ticker-chip">
                <span className="f90-ticker-symbol">{item.ticker}</span>
                <span>{item.name}</span>
                {item.last_close_price && (
                  <span className="f90-ticker-price">
                    ${formatPrice(item.last_close_price)}
                  </span>
                )}
              </span>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}