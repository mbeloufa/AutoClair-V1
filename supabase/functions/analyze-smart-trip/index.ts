import { createClient } from "npm:@supabase/supabase-js@2.111.0";
import { decode } from "npm:@here/flexpolyline@0.1.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const HERE_ROUTE_URL = "https://router.hereapi.com/v8/routes";
const HERE_GEOCODE_URL = "https://geocode.search.hereapi.com/v1/geocode";
const HERE_AUTOSUGGEST_URL =
  "https://autosuggest.search.hereapi.com/v1/autosuggest";
const OFFICIAL_FUEL_DATA_URL =
  "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records";

const MIN_SAVING_EUR = 2.50;
const MIN_SAVING_RATIO = 0.03;
const REQUEST_TIMEOUT_MS = 12000;
const MAX_ROUTE_REQUESTS = 18;
const SEARCH_CONTEXT_FRANCE = { lat: 46.603354, lng: 1.888334 };
const SINGLE_FRACTIONS = [0.35, 0.50, 0.68, 0.82];
const WINDOW_FRACTIONS: Array<[number, number]> = [
  [0.32, 0.60],
  [0.55, 0.82],
];

type Point = { lat: number; lng: number };
type ResolvedPlace = Point & { label: string };

type Candidate = {
  id: string;
  label: string;
  strategy: string;
  complexity_steps: number;
  distance_km: number;
  duration_minutes: number;
  toll_eur: number;
  energy_quantity: number;
  energy_cost_eur: number;
  total_cost_eur: number;
  via_points: Point[];
  points: Point[];
};

type FuelReference = {
  price: number;
  fuelType: string;
  source: string;
  sampleCount: number;
  fetchedAt: string | null;
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const round = (value: number, digits = 2) =>
  Math.round(value * 10 ** digits) / 10 ** digits;

function numberOf(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function pointOf(value: unknown): Point | null {
  if (!value || typeof value !== "object") return null;
  const source = value as Record<string, unknown>;
  const lat = numberOf(source.lat);
  const lng = numberOf(source.lng);
  if (
    lat == null ||
    lng == null ||
    lat < -90 ||
    lat > 90 ||
    lng < -180 ||
    lng > 180
  ) {
    return null;
  }
  return { lat, lng };
}

function clean(value: unknown, max = 160): string {
  return String(value ?? "")
    .trim()
    .replace(/\s+/g, " ")
    .slice(0, max);
}

async function fetchJson(url: URL): Promise<any> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
    const raw = await response.text();
    if (!response.ok) {
      throw new Error(`HERE_${response.status}:${raw.slice(0, 300)}`);
    }
    return JSON.parse(raw);
  } finally {
    clearTimeout(timer);
  }
}

async function geocode(
  query: string,
  apiKey: string,
): Promise<ResolvedPlace> {
  const url = new URL(HERE_GEOCODE_URL);
  url.searchParams.set("q", query);
  url.searchParams.set("limit", "1");
  url.searchParams.set("lang", "fr-FR");
  url.searchParams.set("apiKey", apiKey);
  const data = await fetchJson(url);
  const item = data?.items?.[0];
  const point = pointOf(item?.position);
  if (!point) throw new Error("PLACE_NOT_FOUND");
  return {
    ...point,
    label: clean(item?.title) || clean(item?.address?.label) || query,
  };
}

async function resolvePlace(
  value: unknown,
  apiKey: string,
  fallback: string,
): Promise<ResolvedPlace> {
  if (value && typeof value === "object") {
    const source = value as Record<string, unknown>;
    const point = pointOf(source);
    if (point) {
      return { ...point, label: clean(source.label) || fallback };
    }
    const query = clean(source.query);
    if (query) return geocode(query, apiKey);
  }
  const query = clean(value);
  if (query) return geocode(query, apiKey);
  throw new Error("PLACE_REQUIRED");
}

async function autocomplete(
  query: string,
  context: Point | null,
  apiKey: string,
) {
  if (query.length < 2) return [];
  const at = context ?? SEARCH_CONTEXT_FRANCE;
  const url = new URL(HERE_AUTOSUGGEST_URL);
  url.searchParams.set("q", query);
  url.searchParams.set("at", `${at.lat},${at.lng}`);
  url.searchParams.set("limit", "6");
  url.searchParams.set("lang", "fr-FR");
  url.searchParams.set("apiKey", apiKey);
  const data = await fetchJson(url);
  const items = Array.isArray(data?.items) ? data.items : [];
  const seen = new Set<string>();
  const out: Array<Record<string, unknown>> = [];

  for (const item of items) {
    const resultType = clean(item?.resultType, 40);
    if (resultType === "categoryQuery" || resultType === "chainQuery") continue;
    const point = pointOf(item?.position);
    if (!point) continue;

    const label =
      clean(item?.address?.label) || clean(item?.title) || "Lieu";
    const subtitle = clean(item?.title) === label
      ? ""
      : clean(item?.title);
    const key = `${round(point.lat, 6)}:${round(point.lng, 6)}:${label}`;
    if (seen.has(key)) continue;
    seen.add(key);

    out.push({
      id: clean(item?.id, 240),
      label,
      subtitle,
      lat: point.lat,
      lng: point.lng,
      result_type: resultType,
    });
  }
  return out.slice(0, 6);
}

function addPoints(target: Point[], encoded: unknown) {
  if (typeof encoded !== "string") return;
  try {
    for (const row of decode(encoded).polyline ?? []) {
      if (!Array.isArray(row) || row.length < 2) continue;
      const lat = Number(row[0]);
      const lng = Number(row[1]);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      const last = target[target.length - 1];
      if (
        last &&
        Math.abs(last.lat - lat) < 1e-7 &&
        Math.abs(last.lng - lng) < 1e-7
      ) {
        continue;
      }
      target.push({ lat, lng });
    }
  } catch (_) {
    // Geometry is useful for exploration, never mandatory for the base route.
  }
}

function normalizedFuel(value: unknown): string {
  return String(value ?? "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function isFullElectric(value: unknown): boolean {
  const fuel = normalizedFuel(value);
  return fuel.includes("electri") && !fuel.includes("hybrid");
}

function hereFuelType(value: unknown): "diesel" | "petrol" {
  const fuel = normalizedFuel(value);
  return fuel.includes("diesel") || fuel.includes("gazole")
    ? "diesel"
    : "petrol";
}

function officialFuelCandidates(value: unknown): string[] {
  const fuel = normalizedFuel(value);
  if (fuel.includes("diesel") || fuel.includes("gazole")) return ["Gazole"];
  if (fuel.includes("e85")) return ["E85"];
  if (fuel.includes("gpl")) return ["GPLc"];
  if (fuel.includes("sp98")) return ["SP98"];
  if (fuel.includes("e10")) return ["E10"];
  if (fuel.includes("sp95")) return ["SP95", "E10"];
  return ["SP95", "E10", "SP98"];
}

function estimatedConsumption(value: unknown): number {
  const fuel = normalizedFuel(value);
  if (fuel.includes("diesel") || fuel.includes("gazole")) return 5.4;
  if (fuel.includes("hybrid")) return 5.2;
  if (fuel.includes("gpl")) return 8.2;
  if (fuel.includes("e85")) return 8.0;
  return 6.5;
}

function fuelSpeedTable(
  consumptionPer100: number,
  traffic: boolean,
): string {
  const profile = traffic
    ? [
      [10, 2.10],
      [20, 1.65],
      [30, 1.34],
      [40, 1.16],
      [50, 1.04],
      [60, 0.98],
      [70, 0.96],
      [80, 0.98],
      [90, 1.04],
      [100, 1.10],
      [110, 1.18],
      [120, 1.27],
      [130, 1.37],
    ]
    : [
      [10, 1.55],
      [20, 1.34],
      [30, 1.20],
      [40, 1.08],
      [50, 1.00],
      [60, 0.95],
      [70, 0.93],
      [80, 0.95],
      [90, 1.00],
      [100, 1.07],
      [110, 1.15],
      [120, 1.24],
      [130, 1.34],
    ];
  const base = consumptionPer100 / 100;
  return profile
    .map(([speed, multiplier]) =>
      `${speed},${round(base * multiplier, 5)}`
    )
    .join(",");
}

function distanceMeters(a: Point, b: Point): number {
  const radians = (value: number) => value * Math.PI / 180;
  const lat1 = radians(a.lat);
  const lat2 = radians(b.lat);
  const dLat = lat2 - lat1;
  const dLng = radians(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(dLng / 2) ** 2;
  return 6371000 *
    2 *
    Math.atan2(Math.sqrt(h), Math.sqrt(Math.max(0, 1 - h)));
}

function pointAt(points: Point[], fraction: number): Point | null {
  if (points.length < 3) return null;
  const segments: number[] = [];
  let total = 0;
  for (let index = 1; index < points.length; index += 1) {
    const length = distanceMeters(points[index - 1], points[index]);
    segments.push(length);
    total += length;
  }
  if (total <= 0) {
    return points[Math.floor(points.length * fraction)] ?? null;
  }
  const target = total * Math.max(0, Math.min(1, fraction));
  let walked = 0;
  for (let index = 0; index < segments.length; index += 1) {
    walked += segments[index];
    if (walked >= target) {
      return points[
        Math.min(points.length - 2, Math.max(1, index + 1))
      ] ?? null;
    }
  }
  return points[points.length - 2] ?? null;
}

function candidateFromRoute(
  route: any,
  id: string,
  label: string,
  strategy: string,
  complexity: number,
  viaPoints: Point[],
  consumption: number,
  price: number,
): Candidate | null {
  const sections = Array.isArray(route?.sections) ? route.sections : [];
  if (!sections.length) return null;

  let meters = 0;
  let seconds = 0;
  let toll = 0;
  let hereConsumption = 0;
  let hasHereConsumption = false;
  const points: Point[] = [];

  for (const section of sections) {
    meters += Number(section?.summary?.length ?? 0) || 0;
    seconds += Number(section?.summary?.duration ?? 0) || 0;
    const tollValue = Number(section?.summary?.tolls?.total?.value ?? 0);
    if (Number.isFinite(tollValue) && tollValue > 0) toll += tollValue;

    const sectionConsumption = Number(section?.summary?.consumption);
    if (Number.isFinite(sectionConsumption) && sectionConsumption >= 0) {
      hereConsumption += sectionConsumption;
      hasHereConsumption = true;
    }
    addPoints(points, section?.polyline);
  }

  if (meters <= 0 || seconds <= 0) return null;
  const distanceKm = meters / 1000;
  const energyQuantity = hasHereConsumption
    ? hereConsumption
    : distanceKm / 100 * consumption;
  const energyCost = energyQuantity * price;

  return {
    id,
    label,
    strategy,
    complexity_steps: complexity,
    distance_km: round(distanceKm, 1),
    duration_minutes: round(seconds / 60, 1),
    toll_eur: round(toll),
    energy_quantity: round(energyQuantity, 2),
    energy_cost_eur: round(energyCost),
    total_cost_eur: round(toll + energyCost),
    via_points: [...viaPoints],
    points,
  };
}

function withPrice(candidate: Candidate, price: number): Candidate {
  const energyCost = candidate.energy_quantity * price;
  return {
    ...candidate,
    energy_cost_eur: round(energyCost),
    total_cost_eur: round(candidate.toll_eur + energyCost),
  };
}

async function routeCandidates(
  origin: Point,
  destination: Point,
  apiKey: string,
  consumption: number,
  price: number,
  fuelType: unknown,
  options: {
    prefix: string;
    label: string;
    strategy: string;
    complexity?: number;
    alternatives?: number;
    avoidTolls?: boolean;
    via?: Point[];
  },
  onRequest: () => void,
): Promise<Candidate[]> {
  const url = new URL(HERE_ROUTE_URL);
  url.searchParams.set("transportMode", "car");
  url.searchParams.set("routingMode", "fast");
  url.searchParams.set("origin", `${origin.lat},${origin.lng}`);
  url.searchParams.set("destination", `${destination.lat},${destination.lng}`);
  url.searchParams.set("return", "polyline,summary,tolls");
  url.searchParams.set("currency", "EUR");
  url.searchParams.set("spans", "tollSystems");
  url.searchParams.set("tolls[summaries]", "total");
  url.searchParams.set("departureTime", new Date().toISOString());
  url.searchParams.set("fuel[type]", hereFuelType(fuelType));
  url.searchParams.set(
    "fuel[freeFlowSpeedTable]",
    fuelSpeedTable(consumption, false),
  );
  url.searchParams.set(
    "fuel[trafficSpeedTable]",
    fuelSpeedTable(consumption, true),
  );
  url.searchParams.set("apiKey", apiKey);

  const alternatives = Math.max(
    0,
    Math.min(2, options.alternatives ?? 0),
  );
  if (alternatives) {
    url.searchParams.set("alternatives", String(alternatives));
  }
  if (options.avoidTolls) {
    url.searchParams.set("avoid[features]", "tollRoad");
  }
  for (const via of options.via ?? []) {
    url.searchParams.append(
      "via",
      `${via.lat},${via.lng}!passThrough=true`,
    );
  }

  let data: any;
  try {
    onRequest();
    data = await fetchJson(url);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (
      !message.startsWith("HERE_400") &&
      !message.startsWith("HERE_422")
    ) {
      throw error;
    }
    url.searchParams.delete("fuel[type]");
    url.searchParams.delete("fuel[freeFlowSpeedTable]");
    url.searchParams.delete("fuel[trafficSpeedTable]");
    onRequest();
    data = await fetchJson(url);
  }

  const out: Candidate[] = [];
  const routes = Array.isArray(data?.routes) ? data.routes : [];
  for (let index = 0; index < routes.length; index += 1) {
    const candidate = candidateFromRoute(
      routes[index],
      `${options.prefix}_${index}`,
      index
        ? `${options.label} ${index + 1}`
        : options.label,
      index ? "ALTERNATIVE" : options.strategy,
      options.complexity ?? 0,
      [...(options.via ?? [])],
      consumption,
      price,
    );
    if (candidate) out.push(candidate);
  }
  return out;
}

async function runBatched<T>(
  tasks: Array<() => Promise<T>>,
  batchSize = 3,
): Promise<T[]> {
  const out: T[] = [];
  for (let index = 0; index < tasks.length; index += batchSize) {
    const batch = tasks.slice(index, index + batchSize);
    const settled = await Promise.allSettled(batch.map((task) => task()));
    for (const result of settled) {
      if (result.status === "fulfilled") out.push(result.value);
    }
  }
  return out;
}

function median(values: number[]): number | null {
  const sorted = values
    .filter((value) => Number.isFinite(value) && value > 0)
    .sort((a, b) => a - b);
  if (!sorted.length) return null;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length.isEven
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
}

async function localFuelSamples(
  point: Point,
  fuelType: string,
  supabaseUrl: string,
  anonKey: string,
  authorization: string,
  radiusKm: number,
): Promise<{
  prices: number[];
  ids: string[];
  fetchedAt: string | null;
}> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(
      `${supabaseUrl}/functions/v1/search-fuel-stations`,
      {
        method: "POST",
        headers: {
          Authorization: authorization,
          apikey: anonKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          latitude: point.lat,
          longitude: point.lng,
          radius_km: radiusKm,
          fuel_type: fuelType,
          sort_by: "distance",
          result_limit: 50,
        }),
        signal: controller.signal,
      },
    );
    if (!response.ok) return { prices: [], ids: [], fetchedAt: null };
    const data = await response.json();
    if (data?.success !== true || !Array.isArray(data?.results)) {
      return { prices: [], ids: [], fetchedAt: null };
    }
    const prices: number[] = [];
    const ids: string[] = [];
    for (const station of data.results) {
      if (station?.availability !== "available") continue;
      const price = Number(station?.price);
      const id = clean(station?.station_id, 80);
      if (!Number.isFinite(price) || price <= 0 || !id) continue;
      prices.push(price);
      ids.push(id);
    }
    return {
      prices,
      ids,
      fetchedAt: clean(data?.source_fetched_at, 80) || null,
    };
  } finally {
    clearTimeout(timer);
  }
}

const OFFICIAL_FUEL_FIELDS: Record<string, string> = {
  Gazole: "gazole_prix",
  SP95: "sp95_prix",
  SP98: "sp98_prix",
  E10: "e10_prix",
  E85: "e85_prix",
  GPLc: "gplc_prix",
};

async function nationalFuelSample(
  fuelType: string,
): Promise<number[]> {
  const field = OFFICIAL_FUEL_FIELDS[fuelType];
  if (!field) return [];
  const url = new URL(OFFICIAL_FUEL_DATA_URL);
  url.searchParams.set("limit", "100");
  url.searchParams.set("select", `id,${field}`);
  url.searchParams.set("where", `${field} is not null`);
  url.searchParams.set("order_by", "id desc");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
    if (!response.ok) return [];
    const data = await response.json();
    const records = Array.isArray(data?.results) ? data.results : [];
    return records
      .map((record: any) => Number(record?.[field]))
      .filter((value: number) => Number.isFinite(value) && value > 0);
  } finally {
    clearTimeout(timer);
  }
}

async function fuelReference(
  points: Point[],
  vehicleFuel: unknown,
  supabaseUrl: string,
  anonKey: string,
  authorization: string,
): Promise<FuelReference> {
  const fuelCandidates = officialFuelCandidates(vehicleFuel);

  for (const fuelType of fuelCandidates) {
    const unique = new Map<string, number>();
    const fetchedDates: string[] = [];

    const localResults = await runBatched(
      points.map((point) => () =>
        localFuelSamples(
          point,
          fuelType,
          supabaseUrl,
          anonKey,
          authorization,
          25,
        )
      ),
      3,
    );

    for (const result of localResults) {
      if (result.fetchedAt) fetchedDates.push(result.fetchedAt);
      for (let index = 0; index < result.ids.length; index += 1) {
        unique.set(result.ids[index], result.prices[index]);
      }
    }

    const localPrices = [...unique.values()];
    const localMedian = median(localPrices);
    if (localMedian != null) {
      return {
        price: round(localMedian, 3),
        fuelType,
        source: "OFFICIAL_FRANCE_LOCAL_MEDIAN",
        sampleCount: localPrices.length,
        fetchedAt: fetchedDates.sort().at(-1) ?? null,
      };
    }

    const national = await nationalFuelSample(fuelType);
    const nationalMedian = median(national);
    if (nationalMedian != null) {
      return {
        price: round(nationalMedian, 3),
        fuelType,
        source: "OFFICIAL_FRANCE_SAMPLE_MEDIAN",
        sampleCount: national.length,
        fetchedAt: new Date().toISOString(),
      };
    }
  }

  throw new Error("FUEL_PRICE_UNAVAILABLE");
}

function dedupe(values: Candidate[]): Candidate[] {
  const map = new Map<string, Candidate>();
  for (const candidate of values) {
    const key = [
      Math.round(candidate.distance_km * 2),
      Math.round(candidate.duration_minutes),
      Math.round(candidate.toll_eur * 2),
    ].join(":");
    const existing = map.get(key);
    if (
      !existing ||
      candidate.total_cost_eur < existing.total_cost_eur ||
      (
        Math.abs(candidate.total_cost_eur - existing.total_cost_eur) < 0.01 &&
        candidate.complexity_steps < existing.complexity_steps
      )
    ) {
      map.set(key, candidate);
    }
  }
  return [...map.values()];
}

function pareto(
  values: Candidate[],
): Candidate[] {
  return values.filter((candidate, index) =>
    !values.some((other, otherIndex) => {
      if (index === otherIndex) return false;
      const noWorse =
        other.total_cost_eur <= candidate.total_cost_eur + 0.001 &&
        other.duration_minutes <= candidate.duration_minutes + 0.1 &&
        other.complexity_steps <= candidate.complexity_steps;
      const strictlyBetter =
        other.total_cost_eur < candidate.total_cost_eur - 0.01 ||
        other.duration_minutes < candidate.duration_minutes - 0.1 ||
        other.complexity_steps < candidate.complexity_steps;
      return noWorse && strictlyBetter;
    })
  );
}

function publicCandidate(candidate: Candidate) {
  return {
    id: candidate.id,
    label: candidate.label,
    strategy: candidate.strategy,
    complexity_steps: candidate.complexity_steps,
    distance_km: candidate.distance_km,
    duration_minutes: candidate.duration_minutes,
    toll_eur: candidate.toll_eur,
    energy_quantity: candidate.energy_quantity,
    energy_cost_eur: candidate.energy_cost_eur,
    total_cost_eur: candidate.total_cost_eur,
  };
}

function navigationPoints(candidate: Candidate): Point[] {
  if (candidate.via_points.length) {
    return candidate.via_points.slice(0, 2);
  }
  if (candidate.points.length < 6) return [];
  return [pointAt(candidate.points, 0.34), pointAt(candidate.points, 0.67)]
    .filter((value): value is Point => value != null);
}

function explorationScore(
  candidate: Candidate,
  baseline: Candidate,
): number {
  const saving = baseline.total_cost_eur - candidate.total_cost_eur;
  const delay = Math.max(
    0,
    candidate.duration_minutes - baseline.duration_minutes,
  );
  return saving - delay * 0.04 - candidate.complexity_steps * 0.15;
}

function maxNaturalExtraDistanceKm(baseline: Candidate): number {
  return round(
    Math.max(12, Math.min(60, baseline.distance_km * 0.25)),
    1,
  );
}

function extraDistanceKm(
  candidate: Candidate,
  baseline: Candidate,
): number {
  return candidate.distance_km - baseline.distance_km;
}

function isNaturalCandidate(
  candidate: Candidate,
  baseline: Candidate,
  maxDelay: number,
): boolean {
  const delay =
    candidate.duration_minutes - baseline.duration_minutes;
  const extraDistance = extraDistanceKm(candidate, baseline);
  return delay <= maxDelay + 0.25 &&
    extraDistance <= maxNaturalExtraDistanceKm(baseline) + 0.1;
}

function isExplorationCandidate(
  candidate: Candidate,
  baseline: Candidate,
  maxDelay: number,
): boolean {
  const delay =
    candidate.duration_minutes - baseline.duration_minutes;
  const extraDistance = extraDistanceKm(candidate, baseline);
  return delay <= maxDelay + 5 &&
    extraDistance <= maxNaturalExtraDistanceKm(baseline) * 1.4;
}

function savingAgainst(
  candidate: Candidate,
  baseline: Candidate,
): number {
  return baseline.total_cost_eur - candidate.total_cost_eur;
}

function isEligibleDirectCandidate(
  candidate: Candidate,
  baseline: Candidate,
  threshold: number,
  maxDelay: number,
): boolean {
  return candidate.id !== baseline.id &&
    isNaturalCandidate(candidate, baseline, maxDelay) &&
    savingAgainst(candidate, baseline) >= threshold;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json(405, { success: false, error: "METHOD_NOT_ALLOWED" });
  }

  const requestId = crypto.randomUUID();

  try {
    const apiKey = Deno.env.get("HERE_API_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!apiKey || !supabaseUrl || !anonKey || !serviceRole) {
      return json(503, {
        success: false,
        error: "SMART_TRIP_NOT_CONFIGURED",
        request_id: requestId,
      });
    }

    const authorization = request.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) {
      return json(401, {
        success: false,
        error: "AUTH_REQUIRED",
        request_id: requestId,
      });
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const admin = createClient(supabaseUrl, serviceRole, {
      auth: { persistSession: false },
    });
    const token = authorization.slice("Bearer ".length);
    const { data: authData, error: authError } =
      await userClient.auth.getUser(token);
    const user = authData?.user;
    if (authError || !user) {
      return json(401, {
        success: false,
        error: "AUTH_REQUIRED",
        request_id: requestId,
      });
    }

    const body = await request.json().catch(() => ({}));
    const mode = clean(body?.mode, 40) || "analyze";

    if (mode === "autocomplete") {
      const query = clean(body?.query, 120);
      if (query.length < 2) {
        return json(200, {
          success: true,
          mode: "autocomplete",
          suggestions: [],
        });
      }
      const context = pointOf(body?.at);
      const suggestions = await autocomplete(query, context, apiKey);
      return json(200, {
        success: true,
        mode: "autocomplete",
        suggestions,
      });
    }

    if (mode !== "analyze") {
      return json(400, {
        success: false,
        error: "INVALID_MODE",
        request_id: requestId,
      });
    }

    const vehicleId = clean(body?.vehicle_id, 80);
    const rawConsumption = body?.consumption_per_100;
    const userConsumption = rawConsumption == null ||
        String(rawConsumption).trim() === ""
      ? null
      : numberOf(rawConsumption);
    const maxDelay = numberOf(body?.max_extra_minutes);

    if (!vehicleId) {
      return json(400, {
        success: false,
        error: "VEHICLE_REQUIRED",
        request_id: requestId,
      });
    }
    if (
      (
        userConsumption != null &&
        (userConsumption < 0.5 || userConsumption > 35)
      ) ||
      maxDelay == null ||
      maxDelay < 0 ||
      maxDelay > 30
    ) {
      return json(400, {
        success: false,
        error: "INVALID_FINANCIAL_INPUT",
        request_id: requestId,
      });
    }

    const { data: vehicle, error: vehicleError } = await admin
      .from("vehicles")
      .select("id,user_id,make,model,fuel_type")
      .eq("id", vehicleId)
      .maybeSingle();

    if (vehicleError || !vehicle || vehicle.user_id !== user.id) {
      return json(404, {
        success: false,
        error: "VEHICLE_NOT_FOUND",
        request_id: requestId,
      });
    }
    if (isFullElectric(vehicle.fuel_type)) {
      return json(422, {
        success: false,
        error: "EV_NOT_SUPPORTED_V2",
        request_id: requestId,
      });
    }

    const consumption = userConsumption ??
      estimatedConsumption(vehicle.fuel_type);
    const consumptionSource = userConsumption == null
      ? "ESTIMATED_BY_FUEL"
      : "USER";

    const origin = await resolvePlace(body?.origin, apiKey, "Ma position");
    const destination = await resolvePlace(
      body?.destination,
      apiKey,
      "Destination",
    );

    let routeRequests = 0;
    const onRouteRequest = () => {
      routeRequests += 1;
      if (routeRequests > MAX_ROUTE_REQUESTS) {
        throw new Error("SIMULATION_BUDGET_EXCEEDED");
      }
    };

    const fastestRaw = await routeCandidates(
      origin,
      destination,
      apiKey,
      consumption,
      1,
      vehicle.fuel_type,
      {
        prefix: "FASTEST",
        label: "Trajet rapide",
        strategy: "FASTEST",
        alternatives: 2,
      },
      onRouteRequest,
    );
    if (!fastestRaw.length) throw new Error("NO_ROUTE");

    const provisionalBaseline = fastestRaw[0];
    const fuelPoints = [
      origin,
      pointAt(provisionalBaseline.points, 0.50),
      destination,
    ].filter((value): value is Point => value != null);

    const fuel = await fuelReference(
      fuelPoints,
      vehicle.fuel_type,
      supabaseUrl,
      anonKey,
      authorization,
    );

    const fastest = fastestRaw.map((candidate) =>
      withPrice(candidate, fuel.price)
    );
    const baseline = fastest[0];
    const threshold = Math.max(
      MIN_SAVING_EUR,
      baseline.total_cost_eur * MIN_SAVING_RATIO,
    );

    let noToll: Candidate[] = [];
    try {
      noToll = (await routeCandidates(
        origin,
        destination,
        apiKey,
        consumption,
        fuel.price,
        vehicle.fuel_type,
        {
          prefix: "NO_TOLL",
          label: "Sans péage",
          strategy: "NO_TOLL",
          complexity: 1,
          alternatives: 1,
          avoidTolls: true,
        },
        onRouteRequest,
      )).map((candidate) => withPrice(candidate, fuel.price));
    } catch (_) {
      noToll = [];
    }

    const all: Candidate[] = [...fastest, ...noToll];
    const noTollReference = noToll[0];

    const directCandidates = dedupe(all);
    const directSavingExists = directCandidates.some((candidate) =>
      isEligibleDirectCandidate(
        candidate,
        baseline,
        threshold,
        maxDelay,
      )
    );

    const noTollPotential = noTollReference != null &&
      baseline.toll_eur >= 1.50 &&
      (
        baseline.toll_eur - noTollReference.toll_eur
      ) >= Math.max(1.50, threshold * 0.45) &&
      (
        noTollReference.duration_minutes -
        baseline.duration_minutes
      ) <= Math.max(maxDelay + 8, 12) &&
      extraDistanceKm(noTollReference, baseline) <=
        maxNaturalExtraDistanceKm(baseline) * 1.8;

    const adaptiveSearchUsed =
      !directSavingExists &&
      maxDelay >= 3 &&
      noTollPotential;

    if (noTollReference && adaptiveSearchUsed) {
      const singleTasks = SINGLE_FRACTIONS
        .map((fraction, index) => {
          const via = pointAt(noTollReference.points, fraction);
          if (!via) return null;
          return async () => {
            const candidates = await routeCandidates(
              origin,
              destination,
              apiKey,
              consumption,
              fuel.price,
              vehicle.fuel_type,
              {
                prefix: `SMART_SINGLE_${index}`,
                label: "Détour optimisé",
                strategy: "SMART_SINGLE",
                complexity: 1,
                via: [via],
              },
              onRouteRequest,
            );
            return {
              fraction,
              point: via,
              candidate: candidates[0] ?? null,
            };
          };
        })
        .filter(
          (
            task,
          ): task is () => Promise<{
            fraction: number;
            point: Point;
            candidate: Candidate | null;
          }> => task != null,
        );

      const singleResults = await runBatched(singleTasks, 3);
      for (const result of singleResults) {
        if (result.candidate) all.push(result.candidate);
      }

      const windowTasks = WINDOW_FRACTIONS
        .map(([start, end], index) => {
          const first = pointAt(noTollReference.points, start);
          const second = pointAt(noTollReference.points, end);
          if (!first || !second) return null;
          return async () => {
            const candidates = await routeCandidates(
              origin,
              destination,
              apiKey,
              consumption,
              fuel.price,
              vehicle.fuel_type,
              {
                prefix: `SMART_WINDOW_${index}`,
                label: "Portion hors péage optimisée",
                strategy: "SMART_WINDOW",
                complexity: 2,
                via: [first, second],
              },
              onRouteRequest,
            );
            return candidates[0] ?? null;
          };
        })
        .filter(
          (
            task,
          ): task is () => Promise<Candidate | null> => task != null,
        );

      const windowResults = await runBatched(windowTasks, 3);
      for (const candidate of windowResults) {
        if (candidate) all.push(candidate);
      }

      const promisingSingles = singleResults
        .filter((result) => result.candidate != null)
        .filter((result) =>
          isExplorationCandidate(
            result.candidate!,
            baseline,
            maxDelay,
          )
        )
        .sort((left, right) =>
          explorationScore(right.candidate!, baseline) -
          explorationScore(left.candidate!, baseline)
        )
        .slice(0, 2);

      const comboTasks: Array<() => Promise<Candidate | null>> = [];
      for (let left = 0; left < promisingSingles.length; left += 1) {
        for (
          let right = left + 1;
          right < promisingSingles.length;
          right += 1
        ) {
          const pair = [
            promisingSingles[left],
            promisingSingles[right],
          ].sort((a, b) => a.fraction - b.fraction);
          comboTasks.push(async () => {
            const candidates = await routeCandidates(
              origin,
              destination,
              apiKey,
              consumption,
              fuel.price,
              vehicle.fuel_type,
              {
                prefix: `SMART_COMBO_${left}_${right}`,
                label: "Combinaison optimisée",
                strategy: "SMART_COMBO",
                complexity: 2,
                via: [pair[0].point, pair[1].point],
              },
              onRouteRequest,
            );
            return candidates[0] ?? null;
          });
        }
      }

      const comboResults = await runBatched(comboTasks, 3);
      for (const candidate of comboResults) {
        if (candidate) all.push(candidate);
      }
    }

    const candidates = dedupe(all);
    const sensibleCandidates = candidates.filter((candidate) =>
      candidate.id === baseline.id ||
      isNaturalCandidate(candidate, baseline, maxDelay)
    );
    const frontier = pareto(sensibleCandidates);

    const eligible = frontier
      .filter((candidate) => candidate.id !== baseline.id)
      .map((candidate) => ({
        candidate,
        delay:
          candidate.duration_minutes - baseline.duration_minutes,
        saving:
          baseline.total_cost_eur - candidate.total_cost_eur,
      }))
      .filter((item) =>
        item.delay <= maxDelay + 0.25 &&
        item.saving >= threshold
      );

    let winner = baseline;
    if (eligible.length) {
      const maxSaving = Math.max(...eligible.map((item) => item.saving));
      const tolerance = Math.max(1, maxSaving * 0.15);
      const nearBest = eligible
        .filter((item) => item.saving >= maxSaving - tolerance)
        .sort((left, right) => {
          if (
            left.candidate.complexity_steps !==
              right.candidate.complexity_steps
          ) {
            return left.candidate.complexity_steps -
              right.candidate.complexity_steps;
          }
          if (Math.abs(left.delay - right.delay) > 0.5) {
            return left.delay - right.delay;
          }
          return right.saving - left.saving;
        });
      winner = nearBest[0]?.candidate ?? baseline;
    }

    const netSaving = round(
      baseline.total_cost_eur - winner.total_cost_eur,
    );
    const status = winner.id === baseline.id
      ? "BASELINE_BEST"
      : "SAVING_FOUND";

    return json(200, {
      success: true,
      status,
      request_id: requestId,
      method: "ADAPTIVE_BEAM_V2",
      simulation_strategy:
        "PARETO_MULTI_PASS_NO_TOLL_CORRIDOR",
      origin,
      destination,
      vehicle: {
        id: vehicle.id,
        make: vehicle.make,
        model: vehicle.model,
        fuel_type: vehicle.fuel_type,
      },
      fuel_price_reference: {
        price_eur_per_l: fuel.price,
        fuel_type: fuel.fuelType,
        source: fuel.source,
        sample_count: fuel.sampleCount,
        source_fetched_at: fuel.fetchedAt,
      },
      consumption_reference: {
        consumption_per_100: round(consumption, 2),
        source: consumptionSource,
      },
      baseline: publicCandidate(baseline),
      recommended: publicCandidate(winner),
      comparison: {
        extra_minutes: round(
          winner.duration_minutes - baseline.duration_minutes,
          1,
        ),
        extra_km: round(
          winner.distance_km - baseline.distance_km,
          1,
        ),
        toll_saving_eur: round(
          baseline.toll_eur - winner.toll_eur,
        ),
        energy_cost_delta_eur: round(
          winner.energy_cost_eur - baseline.energy_cost_eur,
        ),
        net_saving_eur: netSaving,
        percent_saving: baseline.total_cost_eur > 0
          ? round(
            netSaving / baseline.total_cost_eur * 100,
            1,
          )
          : 0,
      },
      navigation_waypoints: navigationPoints(winner),
      adaptive_search_used: adaptiveSearchUsed,
      selection_policy: "NATURAL_ROUTE_GUARD_V2_2",
      tested_routes: candidates.length,
      considered_routes: sensibleCandidates.length,
      pareto_routes: frontier.length,
      route_requests: routeRequests,
      max_natural_extra_distance_km:
        maxNaturalExtraDistanceKm(baseline),
      saving_threshold_eur: round(threshold),
    });
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : String(error);
    let code = "SMART_TRIP_SERVICE_ERROR";
    let status = 500;

    if (
      message === "PLACE_REQUIRED" ||
      message === "PLACE_NOT_FOUND"
    ) {
      code = message;
      status = 400;
    } else if (message === "FUEL_PRICE_UNAVAILABLE") {
      code = "FUEL_PRICE_UNAVAILABLE";
      status = 503;
    } else if (message === "NO_ROUTE") {
      code = "NO_ROUTE";
      status = 404;
    } else if (message.startsWith("HERE_429")) {
      code = "ROUTING_TEMPORARILY_BUSY";
      status = 503;
    } else if (
      message.startsWith("HERE_401") ||
      message.startsWith("HERE_403")
    ) {
      code = "ROUTING_CONFIGURATION_ERROR";
      status = 503;
    } else if (message.startsWith("HERE_")) {
      code = "ROUTING_SERVICE_ERROR";
      status = 502;
    } else if (message.toLowerCase().includes("abort")) {
      code = "ROUTING_TIMEOUT";
      status = 504;
    }

    console.error("analyze-smart-trip-v2", {
      request_id: requestId,
      code,
      internal_error: message
        .slice(0, 240)
        .replace(/apiKey=[^&\s]+/gi, "apiKey=[redacted]"),
    });

    return json(status, {
      success: false,
      error: code,
      request_id: requestId,
    });
  }
});
