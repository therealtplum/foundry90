import { InstrumentsPageShell } from "../../components/instruments/InstrumentsPageShell";
import { getInstruments } from "../../lib/api";

export const dynamic = "force-dynamic";

export default async function InstrumentsPage() {
  const instruments = await getInstruments();

  return <InstrumentsPageShell instruments={instruments} />;
}
