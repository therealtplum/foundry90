"use client";

import { useEffect, useState, useTransition } from "react";
import {
  InstrumentInsight,
  getInstrumentOverviewInsight
} from "../../lib/api";
import { MarkdownCard } from "../ui/MarkdownCard";

interface Props {
  instrumentId: number;
}

export function InsightPanel({ instrumentId }: Props) {
  const [insight, setInsight] = useState<InstrumentInsight | null>(null);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    startTransition(() => {
      getInstrumentOverviewInsight(instrumentId)
        .then((data) => {
          setInsight(data);
          setError(null);
        })
        .catch((err) => {
          console.error(err);
          setError("Failed to load insight");
        });
    });
  }, [instrumentId]);

  return (
    <section className="mt-2">
      <div className="flex items-center justify-between mb-2">
        <h2 className="text-sm font-semibold text-slate-100">
          LLM Insight (Overview, 30d)
        </h2>
        <div className="flex items-center gap-3 text-xs text-slate-400">
          {insight && (
            <>
              <span className="rounded-full border border-emerald-500/40 px-2 py-0.5 text-[10px] text-emerald-300">
                {insight.source === "cache" ? "cache" : "fresh LLM"}
              </span>
              <span className="font-mono text-[10px]">
                {insight.model ?? "gpt-4.1-mini"}
              </span>
            </>
          )}
          <button
            className="rounded-md border border-slate-700 bg-slate-900/60 px-2 py-1 text-[11px] text-slate-200 hover:bg-slate-800/80 transition"
            disabled={isPending}
            onClick={() =>
              startTransition(() => {
                getInstrumentOverviewInsight(instrumentId)
                  .then((data) => {
                    setInsight(data);
                    setError(null);
                  })
                  .catch((err) => {
                    console.error(err);
                    setError("Failed to refresh insight");
                  });
              })
            }
          >
            {isPending ? "Refreshing…" : "Refresh"}
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-md border border-red-600/60 bg-red-950/40 px-3 py-2 text-xs text-red-200">
          {error}
        </div>
      )}

      {!insight && !error && (
        <div className="rounded-md border border-slate-800 bg-slate-900/40 px-3 py-8 text-sm text-slate-400 text-center">
          Generating overview with LLM…
        </div>
      )}

      {insight && !error && (
        <MarkdownCard markdown={insight.content_markdown} />
      )}
    </section>
  );
}
