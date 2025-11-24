import Link from "next/link";
import { InstrumentSummary } from "../../lib/api";

interface SidebarProps {
  instruments: InstrumentSummary[];
  activeId?: number;
}

export function Sidebar({ instruments, activeId }: SidebarProps) {
  return (
    <aside className="w-80 border-r border-slate-800 bg-slate-950/70 overflow-y-auto">
      <div className="px-4 py-2 border-b border-slate-800">
        <h2 className="text-xs font-semibold text-slate-400 uppercase tracking-wide">
          Instruments
        </h2>
      </div>
      <nav className="divide-y divide-slate-900/80">
        {instruments.map((inst) => {
          const isActive = inst.id === activeId;
          return (
            <Link
              key={inst.id}
              href={`/instruments/${inst.id}`}
              className={`block px-4 py-3 text-sm transition-colors ${
                isActive
                  ? "bg-slate-800 text-slate-50"
                  : "text-slate-200 hover:bg-slate-900/80 hover:text-slate-50"
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="font-semibold">{inst.ticker}</span>
                <span className="text-[10px] uppercase tracking-wide text-slate-400">
                  {inst.asset_class}
                </span>
              </div>
              <div className="text-xs text-slate-400 truncate">
                {inst.name}
              </div>
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
