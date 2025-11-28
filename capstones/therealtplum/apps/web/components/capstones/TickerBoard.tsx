// apps/web/components/capstones/TickerBoard.tsx
import FocusTickerStrip from "./FocusTickerStrip";
import ComingSoonPill from "./ComingSoonPill";

export default function TickerBoard() {
  return (
    <div className="fmhub-board-root">
      <FocusTickerStrip />
      <ComingSoonPill />
    </div>
  );
}