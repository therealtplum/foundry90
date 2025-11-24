import { InstrumentSummary } from "../../lib/api";
import { TopNav } from "../layout/TopNav";
import { Sidebar } from "../layout/Sidebar";
import { EmptyState } from "../ui/EmptyState";

interface Props {
  instruments: InstrumentSummary[];
}

export function InstrumentsPageShell({ instruments }: Props) {
  const first = instruments[0];

  return (
    <div className="flex min-h-screen flex-col">
      <TopNav />
      <div className="flex flex-1">
        <Sidebar instruments={instruments} activeId={first?.id} />
        <main className="flex-1 bg-slate-950">
          {first ? (
            <div className="h-full flex items-center justify-center text-slate-500">
              Select an instrument on the left, or start with{" "}
              <span className="ml-1 font-semibold text-slate-200">
                {first.ticker}
              </span>
              .
            </div>
          ) : (
            <EmptyState />
          )}
        </main>
      </div>
    </div>
  );
}
