import { InstrumentDetail } from "../../lib/api";
import { TopNav } from "../layout/TopNav";
import { Sidebar } from "../layout/Sidebar";
import { InsightPanel } from "./InsightPanel";
import { getInstruments } from "../../lib/api";

interface Props {
  instrument: InstrumentDetail;
}

export async function InstrumentDetailView({ instrument }: Props) {
  // Load list for sidebar on the server
  const instruments = await getInstruments();

  return (
    <div className="flex min-h-screen flex-col">
      <TopNav />
      <div className="flex flex-1">
        <Sidebar instruments={instruments} activeId={instrument.id} />
        <main className="flex-1 bg-slate-950">
          <div className="max-w-5xl mx-auto px-8 py-6 flex flex-col gap-6">
            <header className="flex items-baseline justify-between gap-4">
              <div>
                <div className="flex items-center gap-3">
                  <h1 className="text-2xl font-semibold tracking-tight">
                    {instrument.ticker}
                  </h1>
                  <span className="rounded-full border border-slate-700 px-2 py-0.5 text-[11px] uppercase tracking-wide text-slate-300">
                    {instrument.asset_class}
                  </span>
                </div>
                <p className="mt-1 text-sm text-slate-400">
                  {instrument.name}
                </p>
              </div>
              <div className="text-right text-xs text-slate-400">
                <div>Exchange: {instrument.exchange ?? "—"}</div>
                <div>
                  Region: {instrument.region ?? "—"} ·{" "}
                  {instrument.country_code ?? "—"}
                </div>
                <div>Currency: {instrument.currency_code}</div>
              </div>
            </header>

            <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-3 text-xs text-slate-300">
                <div className="text-[10px] uppercase tracking-wide text-slate-500 mb-1">
                  Source
                </div>
                <div className="font-mono text-[11px]">
                  {instrument.primary_source}
                </div>
              </div>
              <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-3 text-xs text-slate-300">
                <div className="text-[10px] uppercase tracking-wide text-slate-500 mb-1">
                  Status
                </div>
                <div className="font-semibold">{instrument.status}</div>
              </div>
              <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-3 text-xs text-slate-300">
                <div className="text-[10px] uppercase tracking-wide text-slate-500 mb-1">
                  Horizon
                </div>
                <div>30 days (overview)</div>
              </div>
            </section>

            <InsightPanel instrumentId={instrument.id} />
          </div>
        </main>
      </div>
    </div>
  );
}
