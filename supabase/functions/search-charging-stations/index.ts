import { createClient } from "npm:@supabase/supabase-js@2";

const SOURCE_API =
  "https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets/bornes-irve/records";
const CACHE_TTL_MINUTES = 15;
const CACHE_VERSION = 2;
const PAGE_SIZE = 100;
const MAX_SOURCE_RECORDS = 5000;
const MAX_CONCURRENT_REQUESTS = 5;

const responseHeaders = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SearchRequest = {
  latitude?: unknown;
  longitude?: unknown;
  radius_km?: unknown;
  connector?: unknown;
  minimum_power_kw?: unknown;
  energy_kwh?: unknown;
  sort_by?: unknown;
  result_limit?: unknown;
};

type SourceRecord = Record<string, unknown>;

type SourceResponse = {
  total_count?: number;
  results?: SourceRecord[];
};

type ParsedTariff = {
  kind: "free" | "kwh" | "complex" | "unknown";
  comparable: boolean;
  unitPricePerKwh: number | null;
  sessionFee: number | null;
  estimatedCost: number | null;
};

type PointCandidate = {
  pointId: string;
  stationId: string;
  stationName: string;
  networkName: string;
  operatorName: string;
  operatorPhone: string | null;
  address: string;
  latitude: number;
  longitude: number;
  distanceKm: number;
  powerKw: number;
  connectors: string[];
  pointCount: number;
  isFree: boolean;
  tariffText: string | null;
  tariff: ParsedTariff;
  paymentAtTerminal: boolean;
  paymentCard: boolean;
  paymentOther: boolean;
  accessCondition: string | null;
  reservation: boolean;
  hours: string | null;
  accessibility: string | null;
  updatedAt: string | null;
};

type StationResult = {
  station_id: string;
  station_name: string;
  network_name: string;
  operator_name: string;
  operator_phone: string | null;
  address: string;
  latitude: number;
  longitude: number;
  distance_km: number;
  max_power_kw: number;
  connectors: string[];
  point_count: number;
  is_free: boolean;
  pricing_kind: ParsedTariff["kind"];
  pricing_comparable: boolean;
  unit_price_per_kwh: number | null;
  session_fee: number | null;
  estimated_cost: number | null;
  tariff_text: string | null;
  payment_at_terminal: boolean;
  payment_card: boolean;
  payment_other: boolean;
  access_condition: string | null;
  reservation: boolean;
  hours: string | null;
  accessibility: string | null;
  updated_at: string | null;
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: responseHeaders,
  });
}

function normalizeText(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

function normalizeNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;

  const parsed = Number(
    String(value).trim().replace(/\s/g, "").replace(",", "."),
  );
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeBoolean(value: unknown): boolean {
  if (value === true || value === 1) return true;
  const text = normalizeText(value)?.toLowerCase();
  return text === "true" || text === "1" || text === "oui" || text === "yes";
}

function normalizeDate(value: unknown): string | null {
  const text = normalizeText(value);
  if (!text) return null;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function requireNumber(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): number {
  const number = normalizeNumber(value);
  if (number === null || number < minimum || number > maximum) {
    throw new Error(
      `${field} doit être compris entre ${minimum} et ${maximum}.`,
    );
  }
  return number;
}

function requireInteger(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
  fallback: number,
): number {
  const number = value === undefined ? fallback : Number(value);
  if (!Number.isInteger(number) || number < minimum || number > maximum) {
    throw new Error(
      `${field} doit être un entier compris entre ${minimum} et ${maximum}.`,
    );
  }
  return number;
}

function normalizeConnector(value: unknown): string {
  const connector = (normalizeText(value) ?? "any").toLowerCase();
  const accepted = new Set(["any", "type2", "ccs", "chademo", "ef", "other"]);
  if (!accepted.has(connector)) {
    throw new Error("Le connecteur demandé est invalide.");
  }
  return connector;
}

function normalizeSort(value: unknown): string {
  const sortBy = (normalizeText(value) ?? "price").toLowerCase();
  if (!["price", "distance", "power"].includes(sortBy)) {
    throw new Error("Le tri doit être price, distance ou power.");
  }
  return sortBy;
}

function parseGeoPoint(record: SourceRecord): { latitude: number; longitude: number } | null {
  const directLatitude = normalizeNumber(record.consolidated_latitude);
  const directLongitude = normalizeNumber(record.consolidated_longitude);
  if (
    directLatitude !== null &&
    directLongitude !== null &&
    directLatitude >= -90 &&
    directLatitude <= 90 &&
    directLongitude >= -180 &&
    directLongitude <= 180
  ) {
    return { latitude: directLatitude, longitude: directLongitude };
  }

  const point = record.geo_point_borne;
  if (point && typeof point === "object") {
    const map = point as Record<string, unknown>;
    const latitude = normalizeNumber(map.lat ?? map.latitude);
    const longitude = normalizeNumber(map.lon ?? map.lng ?? map.longitude);
    if (latitude !== null && longitude !== null) {
      return { latitude, longitude };
    }

    const coordinates = map.coordinates;
    if (Array.isArray(coordinates) && coordinates.length >= 2) {
      const longitudeFromArray = normalizeNumber(coordinates[0]);
      const latitudeFromArray = normalizeNumber(coordinates[1]);
      if (latitudeFromArray !== null && longitudeFromArray !== null) {
        return { latitude: latitudeFromArray, longitude: longitudeFromArray };
      }
    }
  }

  const coordinatesXY = record.coordonneesxy ?? record.coordonneesXY;
  if (Array.isArray(coordinatesXY) && coordinatesXY.length >= 2) {
    const longitude = normalizeNumber(coordinatesXY[0]);
    const latitude = normalizeNumber(coordinatesXY[1]);
    if (latitude !== null && longitude !== null) {
      return { latitude, longitude };
    }
  }

  if (typeof coordinatesXY === "string") {
    const values = coordinatesXY
      .replace(/[\[\]"]/g, "")
      .split(",")
      .map((part) => normalizeNumber(part));
    if (values.length >= 2 && values[0] !== null && values[1] !== null) {
      return { latitude: values[1]!, longitude: values[0]! };
    }
  }

  return null;
}

function toRadians(value: number): number {
  return value * Math.PI / 180;
}

function haversineKm(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
): number {
  const earthRadiusKm = 6371.0088;
  const dLat = toRadians(latitudeB - latitudeA);
  const dLon = toRadians(longitudeB - longitudeA);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(latitudeA)) *
      Math.cos(toRadians(latitudeB)) *
      Math.sin(dLon / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function buildBoundingBox(
  latitude: number,
  longitude: number,
  radiusKm: number,
): {
  minLatitude: number;
  maxLatitude: number;
  minLongitude: number;
  maxLongitude: number;
} {
  const latitudeDelta = radiusKm / 110.574;
  const longitudeScale = Math.max(
    Math.abs(Math.cos(toRadians(latitude))),
    0.01,
  );
  const longitudeDelta = radiusKm / (111.320 * longitudeScale);

  return {
    minLatitude: clamp(latitude - latitudeDelta, -90, 90),
    maxLatitude: clamp(latitude + latitudeDelta, -90, 90),
    minLongitude: clamp(longitude - longitudeDelta, -180, 180),
    maxLongitude: clamp(longitude + longitudeDelta, -180, 180),
  };
}

function formatOdsNumber(value: number): string {
  return value.toFixed(7).replace(/0+$/, "").replace(/\.$/, "");
}

function buildSourceWhereClause(
  latitude: number,
  longitude: number,
  radiusKm: number,
  minimumPowerKw: number,
): string {
  const box = buildBoundingBox(latitude, longitude, radiusKm);
  const clauses = [
    `consolidated_latitude >= ${formatOdsNumber(box.minLatitude)}`,
    `consolidated_latitude <= ${formatOdsNumber(box.maxLatitude)}`,
    `consolidated_longitude >= ${formatOdsNumber(box.minLongitude)}`,
    `consolidated_longitude <= ${formatOdsNumber(box.maxLongitude)}`,
  ];

  if (minimumPowerKw > 0) {
    clauses.push(`puissance_nominale >= ${formatOdsNumber(minimumPowerKw)}`);
  }

  return clauses.join(" and ");
}

async function fetchSourcePage(
  selectFields: string,
  whereClause: string,
  offset: number,
): Promise<SourceResponse> {
  const parameters = new URLSearchParams();
  parameters.set("limit", String(PAGE_SIZE));
  parameters.set("offset", String(offset));
  parameters.set("select", selectFields);
  parameters.set("where", whereClause);
  parameters.set(
    "order_by",
    [
      "consolidated_latitude asc",
      "consolidated_longitude asc",
      "id_station_itinerance asc",
      "id_pdc_itinerance asc",
    ].join(", "),
  );

  const response = await fetch(`${SOURCE_API}?${parameters.toString()}`, {
    headers: {
      Accept: "application/json",
      "User-Agent": "AutoClair-Charging-Comparator/1.1",
    },
    signal: AbortSignal.timeout(45000),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(
      `La source IRVE a répondu HTTP ${response.status}: ${details.substring(0, 500)}`,
    );
  }

  return (await response.json()) as SourceResponse;
}

function normalizeTariffText(value: unknown): string | null {
  const text = normalizeText(value);
  if (!text) return null;
  return text.replace(/\s+/g, " ").trim();
}

function uniqueNumbers(values: number[]): number[] {
  return [...new Set(values.map((value) => Math.round(value * 100000) / 100000))];
}

function parseTariff(
  tariffText: string | null,
  isFree: boolean,
  energyKwh: number,
): ParsedTariff {
  if (isFree) {
    return {
      kind: "free",
      comparable: true,
      unitPricePerKwh: 0,
      sessionFee: 0,
      estimatedCost: 0,
    };
  }

  if (!tariffText) {
    return {
      kind: "unknown",
      comparable: false,
      unitPricePerKwh: null,
      sessionFee: null,
      estimatedCost: null,
    };
  }

  const normalized = tariffText
    .toLowerCase()
    .replace(/\u00a0/g, " ")
    .replace(/,/g, ".");

  if (/(^|\W)gratuit(?:e|ement)?($|\W)/.test(normalized) &&
      !/non\s+gratuit/.test(normalized)) {
    return {
      kind: "free",
      comparable: true,
      unitPricePerKwh: 0,
      sessionFee: 0,
      estimatedCost: 0,
    };
  }

  const kwhRates: number[] = [];
  const euroPerKwh = /(\d+(?:\.\d+)?)\s*(?:€|eur(?:os?)?)\s*(?:ttc\s*)?(?:\/|par)?\s*kwh/gi;
  const centsPerKwh = /(\d+(?:\.\d+)?)\s*(?:ct|cts|centime|centimes)\s*(?:\/|par)?\s*kwh/gi;
  const reversedEuro = /kwh\s*(?:[:=]|à)?\s*(\d+(?:\.\d+)?)\s*(?:€|eur(?:os?)?)/gi;

  for (const expression of [euroPerKwh, reversedEuro]) {
    for (const match of normalized.matchAll(expression)) {
      const value = Number(match[1]);
      if (Number.isFinite(value) && value >= 0 && value <= 5) {
        kwhRates.push(value);
      }
    }
  }
  for (const match of normalized.matchAll(centsPerKwh)) {
    const value = Number(match[1]) / 100;
    if (Number.isFinite(value) && value >= 0 && value <= 5) {
      kwhRates.push(value);
    }
  }

  const sessionFees: number[] = [];
  const sessionExpression = /(\d+(?:\.\d+)?)\s*(?:€|eur(?:os?)?)\s*(?:\/|par|la)?\s*(?:session|charge|recharge|acte)/gi;
  for (const match of normalized.matchAll(sessionExpression)) {
    const value = Number(match[1]);
    if (Number.isFinite(value) && value >= 0 && value <= 100) {
      sessionFees.push(value);
    }
  }

  const uniqueKwhRates = uniqueNumbers(kwhRates);
  const uniqueSessionFees = uniqueNumbers(sessionFees);
  const hasTimePricing = /(minute|heure|hour|\/\s*min|\/\s*h\b)/i.test(normalized);
  const hasConditionalPricing = /(abonn|membre|roaming|itinérance|heure creuse|heure pleine|entre \d|après \d|au-delà|occupation)/i.test(normalized);

  if (
    uniqueKwhRates.length === 1 &&
    uniqueSessionFees.length <= 1 &&
    !hasTimePricing &&
    !hasConditionalPricing
  ) {
    const unitPricePerKwh = uniqueKwhRates[0];
    const sessionFee = uniqueSessionFees[0] ?? 0;
    return {
      kind: "kwh",
      comparable: true,
      unitPricePerKwh,
      sessionFee,
      estimatedCost: Math.round((unitPricePerKwh * energyKwh + sessionFee) * 100) / 100,
    };
  }

  return {
    kind: "complex",
    comparable: false,
    unitPricePerKwh: uniqueKwhRates.length === 1 ? uniqueKwhRates[0] : null,
    sessionFee: uniqueSessionFees.length === 1 ? uniqueSessionFees[0] : null,
    estimatedCost: null,
  };
}

function connectorsFor(record: SourceRecord): string[] {
  const connectors: string[] = [];
  if (normalizeBoolean(record.prise_type_2)) connectors.push("Type 2");
  if (normalizeBoolean(record.prise_type_combo_ccs)) connectors.push("Combo CCS");
  if (normalizeBoolean(record.prise_type_chademo)) connectors.push("CHAdeMO");
  if (normalizeBoolean(record.prise_type_ef)) connectors.push("E/F");
  if (normalizeBoolean(record.prise_type_autre)) connectors.push("Autre");
  return connectors;
}

function connectorMatches(connectors: string[], requested: string): boolean {
  if (requested === "any") return true;
  const target = {
    type2: "Type 2",
    ccs: "Combo CCS",
    chademo: "CHAdeMO",
    ef: "E/F",
    other: "Autre",
  }[requested];
  return target ? connectors.includes(target) : false;
}

function sourceToCandidate(
  record: SourceRecord,
  latitude: number,
  longitude: number,
  energyKwh: number,
): PointCandidate | null {
  const point = parseGeoPoint(record);
  if (!point) return null;

  const powerKw = normalizeNumber(record.puissance_nominale) ?? 0;
  const connectors = connectorsFor(record);
  const isFree = normalizeBoolean(record.gratuit);
  const tariffText = normalizeTariffText(record.tarification);
  const tariff = parseTariff(tariffText, isFree, energyKwh);

  const stationName =
    normalizeText(record.nom_station) ??
    normalizeText(record.nom_enseigne) ??
    "Station de recharge";
  const stationId =
    normalizeText(record.id_station_itinerance) ??
    normalizeText(record.id_station_local) ??
    `${stationName}|${point.latitude.toFixed(5)}|${point.longitude.toFixed(5)}`;

  return {
    pointId:
      normalizeText(record.id_pdc_itinerance) ??
      normalizeText(record.id_pdc_local) ??
      `${stationId}|${powerKw}|${connectors.join("-")}`,
    stationId,
    stationName,
    networkName: normalizeText(record.nom_enseigne) ?? "Réseau non renseigné",
    operatorName: normalizeText(record.nom_operateur) ?? "Opérateur non renseigné",
    operatorPhone: normalizeText(record.telephone_operateur),
    address: normalizeText(record.adresse_station) ?? "Adresse non renseignée",
    latitude: point.latitude,
    longitude: point.longitude,
    distanceKm: haversineKm(latitude, longitude, point.latitude, point.longitude),
    powerKw,
    connectors,
    pointCount: Math.max(1, Math.trunc(normalizeNumber(record.nbre_pdc) ?? 1)),
    isFree,
    tariffText,
    tariff,
    paymentAtTerminal: normalizeBoolean(record.paiement_acte),
    paymentCard: normalizeBoolean(record.paiement_cb),
    paymentOther: normalizeBoolean(record.paiement_autre),
    accessCondition: normalizeText(record.condition_acces),
    reservation: normalizeBoolean(record.reservation),
    hours: normalizeText(record.horaires),
    accessibility: normalizeText(record.accessibilite_pmr),
    updatedAt: normalizeDate(record.date_maj ?? record.last_modified),
  };
}

function chooseBestPricing(points: PointCandidate[]): PointCandidate {
  const comparable = points
    .filter((point) => point.tariff.comparable && point.tariff.estimatedCost !== null)
    .sort((a, b) =>
      (a.tariff.estimatedCost ?? Number.POSITIVE_INFINITY) -
      (b.tariff.estimatedCost ?? Number.POSITIVE_INFINITY)
    );
  if (comparable.length > 0) return comparable[0];

  const withTariff = points.find((point) => point.tariffText !== null);
  return withTariff ?? points[0];
}

function groupStations(points: PointCandidate[]): StationResult[] {
  const groups = new Map<string, PointCandidate[]>();
  for (const point of points) {
    const group = groups.get(point.stationId) ?? [];
    group.push(point);
    groups.set(point.stationId, group);
  }

  const results: StationResult[] = [];
  for (const [stationId, stationPoints] of groups.entries()) {
    const reference = stationPoints[0];
    const bestPricing = chooseBestPricing(stationPoints);
    const connectors = [...new Set(stationPoints.flatMap((point) => point.connectors))].sort();
    const updatedDates = stationPoints
      .map((point) => point.updatedAt)
      .filter((value): value is string => value !== null)
      .sort();

    results.push({
      station_id: stationId,
      station_name: reference.stationName,
      network_name: reference.networkName,
      operator_name: reference.operatorName,
      operator_phone: reference.operatorPhone,
      address: reference.address,
      latitude: reference.latitude,
      longitude: reference.longitude,
      distance_km: Math.round(Math.min(...stationPoints.map((point) => point.distanceKm)) * 100) / 100,
      max_power_kw: Math.max(...stationPoints.map((point) => point.powerKw)),
      connectors,
      point_count: Math.max(...stationPoints.map((point) => point.pointCount)),
      is_free: bestPricing.tariff.kind === "free",
      pricing_kind: bestPricing.tariff.kind,
      pricing_comparable: bestPricing.tariff.comparable,
      unit_price_per_kwh: bestPricing.tariff.unitPricePerKwh,
      session_fee: bestPricing.tariff.sessionFee,
      estimated_cost: bestPricing.tariff.estimatedCost,
      tariff_text: bestPricing.tariffText,
      payment_at_terminal: stationPoints.some((point) => point.paymentAtTerminal),
      payment_card: stationPoints.some((point) => point.paymentCard),
      payment_other: stationPoints.some((point) => point.paymentOther),
      access_condition: reference.accessCondition,
      reservation: stationPoints.some((point) => point.reservation),
      hours: reference.hours,
      accessibility: reference.accessibility,
      updated_at: updatedDates.length > 0 ? updatedDates.at(-1)! : null,
    });
  }
  return results;
}

function sortStations(stations: StationResult[], sortBy: string): StationResult[] {
  return [...stations].sort((a, b) => {
    if (sortBy === "distance") {
      return a.distance_km - b.distance_km ||
        (a.estimated_cost ?? Number.POSITIVE_INFINITY) -
          (b.estimated_cost ?? Number.POSITIVE_INFINITY);
    }
    if (sortBy === "power") {
      return b.max_power_kw - a.max_power_kw || a.distance_km - b.distance_km;
    }

    if (a.pricing_comparable !== b.pricing_comparable) {
      return a.pricing_comparable ? -1 : 1;
    }
    return (a.estimated_cost ?? Number.POSITIVE_INFINITY) -
        (b.estimated_cost ?? Number.POSITIVE_INFINITY) ||
      a.distance_km - b.distance_km;
  });
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: responseHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(
      { success: false, message: "Cette fonction accepte uniquement POST." },
      405,
    );
  }
  if (!request.headers.get("Authorization")) {
    return jsonResponse(
      { success: false, message: "Une session utilisateur est requise." },
      401,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { success: false, message: "Configuration Supabase incomplète." },
      500,
    );
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const body = (await request.json()) as SearchRequest;
    const latitude = requireNumber(body.latitude, "latitude", -90, 90);
    const longitude = requireNumber(body.longitude, "longitude", -180, 180);
    const radiusKm = requireNumber(body.radius_km ?? 20, "radius_km", 1, 100);
    const connector = normalizeConnector(body.connector);
    const minimumPowerKw = requireNumber(
      body.minimum_power_kw ?? 0,
      "minimum_power_kw",
      0,
      500,
    );
    const energyKwh = requireNumber(body.energy_kwh ?? 40, "energy_kwh", 1, 150);
    const sortBy = normalizeSort(body.sort_by);
    const resultLimit = requireInteger(
      body.result_limit,
      "result_limit",
      1,
      100,
      50,
    );

    const cacheIdentity = JSON.stringify({
      cacheVersion: CACHE_VERSION,
      latitude: Math.round(latitude * 1000) / 1000,
      longitude: Math.round(longitude * 1000) / 1000,
      radiusKm,
      connector,
      minimumPowerKw,
      energyKwh,
      sortBy,
      resultLimit,
    });
    const cacheKey = await sha256(cacheIdentity);
    const now = new Date();

    const { data: cached } = await admin
      .from("charging_search_cache")
      .select("payload, source_fetched_at, expires_at")
      .eq("cache_key", cacheKey)
      .gt("expires_at", now.toISOString())
      .maybeSingle();

    if (cached?.payload && typeof cached.payload === "object") {
      return jsonResponse({
        ...(cached.payload as Record<string, unknown>),
        cache_hit: true,
        source_fetched_at: cached.source_fetched_at,
      });
    }

    const selectFields = [
      "nom_operateur",
      "telephone_operateur",
      "nom_enseigne",
      "id_station_itinerance",
      "id_station_local",
      "nom_station",
      "adresse_station",
      "nbre_pdc",
      "id_pdc_itinerance",
      "id_pdc_local",
      "puissance_nominale",
      "prise_type_ef",
      "prise_type_2",
      "prise_type_combo_ccs",
      "prise_type_chademo",
      "prise_type_autre",
      "gratuit",
      "paiement_acte",
      "paiement_cb",
      "paiement_autre",
      "tarification",
      "condition_acces",
      "reservation",
      "horaires",
      "accessibilite_pmr",
      "date_maj",
      "last_modified",
      "consolidated_longitude",
      "consolidated_latitude",
      "geo_point_borne",
    ].join(",");

    const whereClause = buildSourceWhereClause(
      latitude,
      longitude,
      radiusKm,
      minimumPowerKw,
    );

    const firstPage = await fetchSourcePage(selectFields, whereClause, 0);
    const firstPageRecords = Array.isArray(firstPage.results)
      ? firstPage.results
      : [];
    const totalCount = Number(firstPage.total_count ?? firstPageRecords.length);
    const maximumPageCount = Math.ceil(MAX_SOURCE_RECORDS / PAGE_SIZE);
    const requestedPageCount = Math.min(
      Math.ceil(totalCount / PAGE_SIZE),
      maximumPageCount,
    );
    const records: SourceRecord[] = [...firstPageRecords];

    const remainingOffsets = Array.from(
      { length: Math.max(0, requestedPageCount - 1) },
      (_, index) => (index + 1) * PAGE_SIZE,
    );

    for (
      let index = 0;
      index < remainingOffsets.length;
      index += MAX_CONCURRENT_REQUESTS
    ) {
      const offsetBatch = remainingOffsets.slice(
        index,
        index + MAX_CONCURRENT_REQUESTS,
      );
      const pageBatch = await Promise.all(
        offsetBatch.map((offset) =>
          fetchSourcePage(selectFields, whereClause, offset)
        ),
      );

      for (const page of pageBatch) {
        const pageRecords = Array.isArray(page.results) ? page.results : [];
        records.push(...pageRecords);
      }
    }

    const points = records
      .map((record) => sourceToCandidate(record, latitude, longitude, energyKwh))
      .filter((point): point is PointCandidate => point !== null)
      .filter((point) => point.distanceKm <= radiusKm + 0.05)
      .filter((point) => point.powerKw >= minimumPowerKw)
      .filter((point) => connectorMatches(point.connectors, connector));

    const stations = sortStations(groupStations(points), sortBy).slice(0, resultLimit);
    const sourceFetchedAt = now.toISOString();
    const expiresAt = new Date(
      now.getTime() + CACHE_TTL_MINUTES * 60 * 1000,
    ).toISOString();
    const truncated = totalCount > records.length;

    const payload = {
      success: true,
      results: stations,
      result_count: stations.length,
      energy_kwh: energyKwh,
      pricing_disclaimer:
        "Les estimations ne sont calculées que pour les tarifs simples et non conditionnels exprimés en €/kWh. Le texte publié par l'opérateur reste la référence.",
      source_name: "Open Data Réseaux Énergies - consolidation IRVE",
      source_record_count: records.length,
      source_total_count: totalCount,
      source_filter_mode: "consolidated_coordinates_bounding_box",
      truncated,
    };

    await admin.from("charging_search_cache").upsert(
      {
        cache_key: cacheKey,
        payload,
        source_fetched_at: sourceFetchedAt,
        expires_at: expiresAt,
        updated_at: sourceFetchedAt,
      },
      { onConflict: "cache_key" },
    );

    return jsonResponse({
      ...payload,
      cache_hit: false,
      source_fetched_at: sourceFetchedAt,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Charging station search failed", { message });
    const isValidationError =
      message.includes("doit être") || message.includes("invalide");
    return jsonResponse(
      {
        success: false,
        message: isValidationError
          ? message
          : "Impossible de récupérer les bornes de recharge pour le moment.",
      },
      isValidationError ? 400 : 500,
    );
  }
});