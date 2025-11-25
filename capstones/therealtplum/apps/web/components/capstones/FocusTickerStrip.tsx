"use client";

import { useEffect, useState } from "react";
import {
  getFocusTickerStrip,
  type FocusTickerStripItem,
} from "@/lib/api";

type Status = "idle" | "loading" | "loaded" | "error";

function formatPrice(value: string | null): string {
  if (!value) return "--";
  const num = Number(value);
  if (!Number.isFinite(num)) return value;
  return num.toFixed(2);
}

function buildLabel(item: FocusTickerStripItem): string {
  // Try to pull a nice short insight line; fallback to name
  const source = item.short_insight ?? item.recent_insight;
  if (!source) return item.name;

  const firstLine =
    source
      .split("\n")
      .map((l) => l.trim())
      .find((l) => l.length > 0) ?? "";

  // Strip markdown headings like "# Overview: ..."
  return firstLine.replace(/^#+\s*/, "");
}

export default function FocusTickerStrip() {
  const [items, setItems] = useState<FocusTickerStripItem[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setStatus("loading");
        // Pull a decent chunk of the focus universe
        const data = await getFocusTickerStrip(64);
        if (!cancelled) {
          setItems(data);
          setStatus("loaded");
        }
      } catch (err: any) {
        console.error("Focus ticker strip error:", err);
        if (!cancelled) {
          setError("Failed to load focus tickers");
          setStatus("error");
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  if (status === "error") {
    return (
      <div className="w-full h-full flex items-center justify-center text-xs text-emerald-400 bg-black">
        {error}
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div className="w-full h-full flex items-center justify-center text-xs text-emerald-300/70 bg-black animate-pulse">
        Loading focus universe…
      </div>
    );
  }

  // Duplicate the array so we can scroll seamlessly
  const marqueeItems = [...items, ...items];

  return (
    <div className="relative w-full h-full bg-black overflow-hidden border border-emerald-500/40 rounded-xl">
      {/* Left/right fades */}
      <div className="pointer-events-none absolute inset-y-0 left-0 w-24 bg-gradient-to-r from-black to-transparent z-10" />
      <div className="pointer-events-none absolute inset-y-0 right-0 w-24 bg-gradient-to-l from-black to-transparent z-10" />

      <div className="absolute inset-0 opacity-30 pointer-events-none">
        {/* Faux scanline effect */}
        <div className="w-full h-full bg-[radial-gradient(circle_at_0_0,#22c55e0d,transparent_60%),radial-gradient(circle_at_100%_100%,#22c55e0d,transparent_60%)]" />
      </div>

      <div
        className="
          relative z-0 flex items-center gap-4 whitespace-nowrap
          text-[11px] font-mono uppercase tracking-tight
          text-emerald-300
          animate-[ticker-marquee_40s_linear_infinite]
          hover:[animation-play-state:paused]
          px-6 py-3
        "
      >
        {marqueeItems.map((item, idx) => (
          <span
            key={`${item.instrument_id}-${idx}`}
            className="
              inline-flex items-center gap-2 px-3 py-1
              rounded-full border border-emerald-500/60
              bg-emerald-500/10
              shadow-[0_0_10px_rgba(34,197,94,0.4)]
            "
          >
            <span className="text-emerald-300">
              [{item.ticker}]
            </span>
            <span className="text-emerald-200/90 max-w-[260px] truncate normal-case">
              {buildLabel(item)}
            </span>
            <span className="text-emerald-400/90">
              {formatPrice(item.last_close_price)}
            </span>
          </span>
        ))}
      </div>

      <style jsx>{`
        @keyframes ticker-marquee {
          0% {
            transform: translateX(0);
          }
          100% {
            transform: translateX(-50%);
          }
        }
      `}</style>
    </div>
  );
}