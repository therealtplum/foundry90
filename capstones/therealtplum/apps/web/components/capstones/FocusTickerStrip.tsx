"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

/**
 * Static fallback focus universe.
 * This will always be available in the bundle, so Vercel / mobile
 * will show *something* even if the live API is unreachable.
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

/**
 * Try to load the live focus universe from fmhub-api.
 * Returns `null` if anything goes wrong so we can fall back to STATIC_TICKERS.
 */
async function loadLive(limit = 64): Promise<FocusTickerStripItem[] | null> {
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

function formatPrice(raw: string | null): string {
  if (!raw) return "";
  const n = Number(raw);
  if (!Number.isFinite(n)) return raw;
  return n.toFixed(2);
}

export default function FocusTickerStrip() {
  // Start with static data so there's *always* something to render.
  const [items, setItems] = useState<FocusTickerStripItem[]>(STATIC_TICKERS);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      const live = await loadLive(96); // best-effort override
      if (!cancelled && live) {
        setItems(live);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  // Duplicate array so the marquee can loop seamlessly
  const marqueeItems = [...items, ...items];

  // Split into a few rows, alternating left/right
  const ROWS = 4;
  const perRow = Math.ceil(marqueeItems.length / ROWS);
  const rowChunks = Array.from({ length: ROWS }, (_, rowIndex) =>
    marqueeItems.slice(rowIndex * perRow, (rowIndex + 1) * perRow),
  );

  return (
    <div className="relative w-full h-screen bg-black overflow-hidden">
      {/* subtle background glow */}
      <div className="absolute inset-0 bg-gradient-to-b from-black via-black to-black" />

      <div className="relative z-10 flex flex-col justify-center gap-6 h-full px-6">
        {rowChunks.map((row, rowIndex) => (
          <div
            key={rowIndex}
            className={`flex whitespace-nowrap gap-8 font-mono text-emerald-400 text-[18px] leading-tight ${
              rowIndex % 2 === 0 ? "fr-ticker-left" : "fr-ticker-right"
            }`}
            style={{
              animationDuration: rowIndex % 2 === 0 ? "32s" : "40s",
            }}
          >
            {row.map((item, i) => {
              const price = formatPrice(item.last_close_price);
              return (
                <span
                  key={`${item.instrument_id}-${i}`}
                  className="flex items-baseline gap-2"
                >
                  <span className="font-semibold">{item.ticker}</span>
                  <span className="text-emerald-300/90">{item.name}</span>
                  {price && (
                    <span className="text-emerald-500">
                      ${price}
                    </span>
                  )}
                  <span className="mx-4 text-emerald-700">•</span>
                </span>
              );
            })}
          </div>
        ))}
      </div>

      {/* Local CSS-only, no globals.css changes required */}
      <style jsx>{`
        @keyframes fr-ticker-left-anim {
          0% {
            transform: translateX(0);
          }
          100% {
            transform: translateX(-50%);
          }
        }

        @keyframes fr-ticker-right-anim {
          0% {
            transform: translateX(-50%);
          }
          100% {
            transform: translateX(0);
          }
        }

        .fr-ticker-left {
          animation-name: fr-ticker-left-anim;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
        }

        .fr-ticker-right {
          animation-name: fr-ticker-right-anim;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
        }
      `}</style>
    </div>
  );
}