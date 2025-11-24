import { getInstrumentById } from "../../../lib/api";
import { InstrumentDetailView } from "../../../components/instruments/InstrumentDetailView";

export const dynamic = "force-dynamic";

interface Props {
  params: { id: string };
}

export default async function InstrumentDetailPage({ params }: Props) {
  const id = Number(params.id);
  const instrument = await getInstrumentById(id);

  return <InstrumentDetailView instrument={instrument} />;
}
