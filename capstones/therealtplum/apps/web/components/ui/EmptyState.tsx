export function EmptyState() {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-2 text-slate-500">
      <div className="text-sm font-medium">No instruments yet</div>
      <div className="text-xs text-slate-400">
        Seed the database, then refresh this page.
      </div>
    </div>
  );
}
