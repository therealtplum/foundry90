// apps/web/components/capstones/FocusTickerStrip.tsx
"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

/**
 * Static fallback focus universe.
 * Always bundled, so we show something even if fmhub-api is unreachable.
 */
const STATIC_TICKERS: FocusTickerStripItem[] = [
  {
    instrument_id: 32892,
    ticker: "NVDA",
    name: "Nvidia Corp",
    asset_class: "equity",
    last_close_price: 182.55,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 38771,
    ticker: "SPY",
    name: "SPDR S&P 500 ETF Trust",
    asset_class: "equity",
    last_close_price: 668.73,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 35489,
    ticker: "QQQ",
    name: "Invesco QQQ Trust, Series 1",
    asset_class: "equity",
    last_close_price: 605.16,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 40741,
    ticker: "TSLA",
    name: "Tesla, Inc. Common Stock",
    asset_class: "equity",
    last_close_price: 417.78,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 12309,
    ticker: "GOOGL",
    name: "Alphabet Inc. Class A",
    asset_class: "equity",
    last_close_price: 318.58,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 12308,
    ticker: "GOOG",
    name: "Alphabet Inc. Class C",
    asset_class: "equity",
    last_close_price: 318.47,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 30416,
    ticker: "META",
    name: "Meta Platforms, Inc. Class A",
    asset_class: "equity",
    last_close_price: 613.05,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 1334,
    ticker: "AMD",
    name: "Advanced Micro Devices",
    asset_class: "equity",
    last_close_price: 215.05,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 2430,
    ticker: "AVGO",
    name: "Broadcom Inc.",
    asset_class: "equity",
    last_close_price: 377.96,
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 56,
    ticker: "AAPL",
    name: "Apple Inc.",
    asset_class: "equity",
    last_close_price: 275.92,
    short_insight: null,
    recent_insight: null,
  },
];

/**
 * Try to load the live focus universe; return null on any failure
 * so we can fall back to STATIC_TICKERS.
 */
async function loadLive(limit = 80): Promise<FocusTickerStripItem[] | null> {
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

function formatPrice(p: number | null): string {
  if (p == null) return "";
  return `$${p.toFixed(2)}`;
}

export default function FocusTickerStrip() {
  // Start with static so SSR + Vercel always show something.
  const [items, setItems] = useState<FocusTickerStripItem[]>(STATIC_TICKERS);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      const live = await loadLive(120);
      if (!cancelled && live) {
        setItems(live);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  // Limit what we actually put on-screen so it doesn’t become soup.
  const MAX_ITEMS = 48;
  const baseItems =
    items.length > MAX_ITEMS ? items.slice(0, MAX_ITEMS) : items;

  // Duplicate for seamless marquee
  const marqueeItems = [...baseItems, ...baseItems];

  // Split into 4 rows, alternating left/right
  const ROWS = 4;
  const perRow = Math.ceil(marqueeItems.length / ROWS);
  const rowChunks = Array.from({ length: ROWS }, (_, rowIndex) =>
    marqueeItems.slice(rowIndex * perRow, (rowIndex + 1) * perRow),
  );

  return (
    <div className="relative w-full h-screen bg-black overflow-hidden">
      {/* subtle CRT-ish background */}
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(16,185,129,0.22),_transparent_55%),radial-gradient(circle_at_bottom,_rgba(0,0,0,0.9),_black)] opacity-80" />
      <div className="pointer-events-none absolute inset-0 mix-blend-soft-light opacity-40 [background-image:repeating-linear-gradient(to_bottom,rgba(0,0,0,0)_0,rgba(0,0,0,0)_2px,rgba(16,185,129,0.12)_3px,rgba(0,0,0,0)_4px)]" />

      <div className="relative z-10 flex h-full flex-col justify-center gap-6 px-6">
        {rowChunks.map((row, rowIndex) => (
          <div
            key={rowIndex}
            className={`flex whitespace-nowrap gap-10 font-mono text-[18px] md:text-[22px] leading-tight text-emerald-400 drop-shadow-[0_0_8px_rgba(16,185,129,0.8)] ${
              rowIndex % 2 === 0 ? "fr-ticker-left" : "fr-ticker-right"
            }`}
            style={{
              animationDuration: rowIndex % 2 === 0 ? "26s" : "32s",
            }}
          >
            {row.map((item, i) => (
              <span
                key={`${item.instrument_id}-${i}`}
                className="flex items-baseline gap-2"
              >
                <span className="font-bold text-emerald-300">
                  {item.ticker}
                </span>
                <span className="max-w-[260px] truncate text-emerald-200/90">
                  {item.name}
                </span>
                {item.last_close_price != null && (
                  <span className="text-emerald-400">
                    {formatPrice(item.last_close_price)}
                  </span>
                )}
                <span className="mx-5 text-emerald-700">•</span>
              </span>
            ))}
          </div>
        ))}
      </div>

      {/* Local CSS-only animations so we don't touch globals.css */}
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