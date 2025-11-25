"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

type Status = "idle" | "loading" | "loaded";

// ---------------------------------------------------------------------------
// Fallback snapshot – baked into the frontend so Vercel / phones see something
// ---------------------------------------------------------------------------

const FALLBACK_ITEMS: FocusTickerStripItem[] = [
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
    name: "Alphabet Inc. Class A Common Stock",
    asset_class: "equity",
    last_close_price: "318.58",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 12308,
    ticker: "GOOG",
    name: "Alphabet Inc. Class C Capital Stock",
    asset_class: "equity",
    last_close_price: "318.47",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 30416,
    ticker: "META",
    name: "Meta Platforms, Inc. Class A Common Stock",
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
    name: "Broadcom Inc. Common Stock",
    asset_class: "equity",
    last_close_price: "377.96",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99901,
    ticker: "IWM",
    name: "iShares Russell 2000 ETF",
    asset_class: "equity",
    last_close_price: "239.90",
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
    instrument_id: 99902,
    ticker: "MSFT",
    name: "Microsoft Corp",
    asset_class: "equity",
    last_close_price: "474.00",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99903,
    ticker: "AMZN",
    name: "Amazon.com Inc",
    asset_class: "equity",
    last_close_price: "226.28",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99904,
    ticker: "TQQQ",
    name: "ProShares UltraPro QQQ",
    asset_class: "equity",
    last_close_price: "51.08",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99905,
    ticker: "PLTR",
    name: "Palantir Technologies Inc. Class A",
    asset_class: "equity",
    last_close_price: "162.25",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99906,
    ticker: "ORCL",
    name: "Oracle Corp",
    asset_class: "equity",
    last_close_price: "200.28",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99907,
    ticker: "BABA",
    name: "Alibaba Group Holding Ltd.",
    asset_class: "equity",
    last_close_price: "160.73",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99908,
    ticker: "LQD",
    name: "iShares iBoxx $ Investment Grade Corporate Bond ETF",
    asset_class: "equity",
    last_close_price: "111.36",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99909,
    ticker: "HYG",
    name: "iShares iBoxx $ High Yield Corporate Bond ETF",
    asset_class: "equity",
    last_close_price: "80.59",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99910,
    ticker: "VOO",
    name: "Vanguard S&P 500 ETF",
    asset_class: "equity",
    last_close_price: "614.94",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99911,
    ticker: "GLD",
    name: "SPDR Gold Shares",
    asset_class: "equity",
    last_close_price: "380.20",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99912,
    ticker: "LLY",
    name: "Eli Lilly & Co.",
    asset_class: "equity",
    last_close_price: "1070.16",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99913,
    ticker: "SMH",
    name: "VanEck Semiconductor ETF",
    asset_class: "equity",
    last_close_price: "339.12",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99914,
    ticker: "IBIT",
    name: "iShares Bitcoin Trust ETF",
    asset_class: "equity",
    last_close_price: "50.57",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99915,
    ticker: "TLT",
    name: "iShares 20+ Year Treasury Bond ETF",
    asset_class: "equity",
    last_close_price: "90.01",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99916,
    ticker: "MSTR",
    name: "MicroStrategy Inc. Class A",
    asset_class: "equity",
    last_close_price: "179.04",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99917,
    ticker: "COIN",
    name: "Coinbase Global, Inc. Class A",
    asset_class: "equity",
    last_close_price: "255.97",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99918,
    ticker: "NFLX",
    name: "Netflix Inc.",
    asset_class: "equity",
    last_close_price: "106.97",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99919,
    ticker: "BRK.B",
    name: "Berkshire Hathaway Class B",
    asset_class: "equity",
    last_close_price: "507.81",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99920,
    ticker: "WMT",
    name: "Walmart Inc.",
    asset_class: "equity",
    last_close_price: "104.06",
    short_insight: null,
    recent_insight: null,
  },
  {
    instrument_id: 99921,
    ticker: "SOFI",
    name: "SoFi Technologies, Inc.",
    asset_class: "equity",
    last_close_price: "27.40",
    short_insight: null,
    recent_insight: null,
  },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatPrice(value: string | null): string {
  if (!value) return "--";
  const num = Number(value);
  if (!Number.isFinite(num)) return value;
  return `$${num.toFixed(2)}`;
}

function chunkIntoRows<T>(items: T[], rowCount: number): T[][] {
  if (items.length === 0 || rowCount <= 0) return [];
  const limited = items.slice(0, 48); // don’t need the whole universe to look full
  const perRow = Math.ceil(limited.length / rowCount);
  const rows: T[][] = [];
  for (let i = 0; i < rowCount; i++) {
    const start = i * perRow;
    const end = start + perRow;
    if (start < limited.length) {
      rows.push(limited.slice(start, end));
    }
  }
  return rows;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function FocusTickerStrip() {
  const [items, setItems] = useState<FocusTickerStripItem[]>([]);
  const [status, setStatus] = useState<Status>("idle");

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setStatus("loading");
        const data = await getFocusTickerStrip(80);
        if (!cancelled && data && data.length > 0) {
          setItems(data);
          setStatus("loaded");
          return;
        }
      } catch (err: any) {
        console.error("Focus ticker strip error:", err);
      }

      // If we got here, either API unavailable or returned nothing — use fallback
      if (!cancelled) {
        setItems(FALLBACK_ITEMS);
        setStatus("loaded");
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  if (status === "idle" || items.length === 0) {
    return (
      <div className="w-full h-full flex items-center justify-center bg-black text-[#43ff8a] font-mono text-sm">
        Booting focus universe…
      </div>
    );
  }

  const rows = chunkIntoRows(items, 6);

  return (
    <div className="relative w-full h-[70vh] md:h-[80vh] bg-black overflow-hidden">
      {/* subtle glow grid */}
      <div className="pointer-events-none absolute inset-0 opacity-40 mix-blend-screen">
        <div className="w-full h-full bg-[radial-gradient(circle_at_0_0,#22c55e1a,transparent_55%),radial-gradient(circle_at_100%_100%,#22c55e12,transparent_60%)]" />
      </div>

      <div className="absolute inset-0 flex flex-col justify-center gap-3 px-4 md:px-8">
        {rows.map((row, rowIdx) => {
          const directionClass =
            rowIdx % 2 === 0 ? "animate-ticker-left" : "animate-ticker-right";

          // Slightly vary the speed per row
          const durationSeconds = 26 + rowIdx * 3;

          return (
            <div
              key={rowIdx}
              className={`flex whitespace-nowrap ${directionClass}`}
              style={{ animationDuration: `${durationSeconds}s` }}
            >
              {[...row, ...row].map((item, idx) => (
                <span
                  key={`${rowIdx}-${item.instrument_id}-${idx}`}
                  className="mx-4 flex items-baseline gap-2 font-mono text-[15px] md:text-[18px] tracking-tight text-[#43ff8a] drop-shadow-[0_0_12px_rgba(34,197,94,0.9)]"
                >
                  <span className="font-semibold">
                    {item.ticker}
                  </span>
                  <span className="opacity-80 text-[#bbf7d0]">
                    {item.name}
                  </span>
                  <span className="opacity-90">
                    {formatPrice(item.last_close_price)}
                  </span>
                  <span className="opacity-40 mx-1">…</span>
                </span>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}