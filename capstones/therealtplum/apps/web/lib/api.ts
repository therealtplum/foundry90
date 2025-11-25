export interface InstrumentSummary {
  id: number;
  ticker: string;
  name: string;
  asset_class: string;
}

export interface InstrumentDetail {
  id: number;
  ticker: string;
  name: string;
  asset_class: string;
  exchange: string | null;
  currency_code: string;
  region: string | null;
  country_code: string | null;
  primary_source: string;
  status: string;
}

export interface InstrumentInsight {
  source: "llm" | "cache";
  instrument_id: number;
  insight_type: string;
  horizon_days: number;
  model: string;
  insight_id?: number;
  created_at?: string;
  content_markdown: string;
}

export interface FocusTickerStripItem {
  instrument_id: number;
  ticker: string;
  name: string;
  asset_class: string;
  last_close_price: string | null;
  short_insight: string | null;
  recent_insight: string | null;
}

function getBaseUrl() {
  if (typeof window !== "undefined") {
    return process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:3000";
  }
  return process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:3000";
}

async function apiGet<T>(path: string): Promise<T> {
  const base = getBaseUrl();
  const res = await fetch(`${base}${path}`, {
    method: "GET",
    headers: { "Accept": "application/json" },
    cache: "no-store"
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GET ${path} failed: ${res.status} ${res.statusText} - ${text}`);
  }

  return res.json() as Promise<T>;
}

export async function getInstruments(): Promise<InstrumentSummary[]> {
  return apiGet<InstrumentSummary[]>("/instruments");
}

export async function getInstrumentById(id: number): Promise<InstrumentDetail> {
  return apiGet<InstrumentDetail>(`/instruments/${id}`);
}

export async function getInstrumentOverviewInsight(
  id: number,
  horizon_days: number = 30
): Promise<InstrumentInsight> {
  return apiGet<InstrumentInsight>(
    `/instruments/${id}/insights/overview?horizon_days=${horizon_days}`
  );
}

export async function getFocusTickerStrip(limit: number = 50): Promise<FocusTickerStripItem[]> {
  return apiGet<FocusTickerStripItem[]>(`/focus/ticker-strip?limit=${limit}`);
}