export function TopNav() {
  return (
    <header className="flex items-center justify-between border-b border-slate-800 px-6 py-3 bg-slate-950/80 backdrop-blur">
      <div className="flex items-center gap-2">
        <div className="h-7 w-7 rounded-md bg-emerald-500/20 border border-emerald-400/40 flex items-center justify-center text-xs font-semibold text-emerald-200">
          fm
        </div>
        <div className="flex flex-col leading-tight">
          <span className="text-sm font-semibold text-slate-50 tracking-tight">
            fmhub
          </span>
          <span className="text-xs text-slate-400">
            Foundry90 markets intelligence
          </span>
        </div>
      </div>
      <div className="text-xs text-slate-400">
        API: <span className="text-emerald-300">healthy</span>
      </div>
    </header>
  );
}
