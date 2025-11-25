import FocusTickerStrip from "@/components/capstones/FocusTickerStrip";

export default function CapstonesPage() {
  return (
    <div className="w-full h-screen bg-black text-white relative">
      <div className="absolute inset-0">
        <FocusTickerStrip />
      </div>

      <div className="relative z-10 p-8">
        <h1 className="text-3xl font-bold mb-4">
          Foundry 90 – Market Intelligence Lab
        </h1>
        <p className="text-green-200/80">
          This is your capstone dashboard. Click any streaming ticker above to view insights.
        </p>
      </div>
    </div>
  );
}