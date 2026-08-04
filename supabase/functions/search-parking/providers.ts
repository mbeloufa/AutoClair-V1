import {
  asInteger,
  asNumber,
  asString,
  isRecord,
  safeError,
  type JsonMap,
} from "../_shared/utils.ts";
import {
  type ParkingConfidence,
  type ParkingResult,
  type ParkingStatus,
  type ProviderFetchResult,
  type ProviderSummary,
} from "./types.ts";

type OsmElement = JsonMap & {
  type?: unknown;
  id?: unknown;
  lat?: unknown;
  lon?: unknown;
  center?: unknown;
  tags?: unknown;
};

type OfficialProvider = {
  code: string;
  name: string;
  covers: (
    latitude: number,
    longitude: number,
    radiusKm: number,
  ) => boolean;
  fetch: (
    latitude: number,
    longitude: number,
    radiusKm: number,
  ) => Promise<ParkingResult[]>;
};

const OVERPASS_ENDPOINTS = [
  "https://overpass-api.de/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
];

const DIJON_ENDPOINT =
  "https://data.metropole-dijon.fr/api/explore/v2.1/catalog/datasets/" +
  "dispo-parking/records?limit=100";

const NANTES_STATIC_ENDPOINT =
  "https://data.nantesmetropole.fr/api/explore/v2.1/catalog/datasets/" +
  "244400404_parkings-publics-nantes/records?limit=100";

const NANTES_REALTIME_ENDPOINT =
  "https://data.nantesmetropole.fr/api/explore/v2.1/catalog/datasets/" +
  "244400404_parkings-publics-nantes-disponibilites/records?limit=100";

const NANTES_PR_ENDPOINT =
  "https://data.nantesmetropole.fr/api/explore/v2.1/catalog/datasets/" +
  "244400404_parcs-relais-nantes-metropole-disponibilites/records?limit=100";

const STRASBOURG_STATIC_ENDPOINT =
  "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/" +
  "parkings/records?limit=100";

const STRASBOURG_REALTIME_ENDPOINT =
  "https://data.strasbourg.eu/api/explore/v2.1/catalog/datasets/" +
  "occupation-parkings-temps-reel/records?limit=100";

function parseInteger(value: unknown): number | null {
  const parsed = asInteger(value);
  if (parsed !== null && parsed >= 0) return parsed;
  const text = asString(value);
  const match = text?.match(/\d+/);
  return match ? Number(match[0]) : null;
}

function parseHeight(value: unknown): number | null {
  const text = asString(value)?.replace(",", ".");
  const match = text?.match(/(\d+(?:\.\d+)?)/);
  if (!match) return null;
  const parsed = Number(match[1]);
  return parsed > 0 && parsed < 10 ? parsed : null;
}

export function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const radius = 6371.0088;
  const dLat = radians(lat2 - lat1);
  const dLon = radians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(lat1)) *
      Math.cos(radians(lat2)) *
      Math.sin(dLon / 2) ** 2;
  return 2 * radius * Math.asin(Math.sqrt(a));
}

function coordinate(value: unknown): {
  latitude: number;
  longitude: number;
} | null {
  if (isRecord(value)) {
    const latitude = asNumber(value.lat) ?? asNumber(value.latitude);
    const longitude =
      asNumber(value.lon) ??
      asNumber(value.lng) ??
      asNumber(value.longitude);
    if (latitude !== null && longitude !== null) {
      return { latitude, longitude };
    }
  }

  if (Array.isArray(value) && value.length >= 2) {
    const latitude = asNumber(value[0]);
    const longitude = asNumber(value[1]);
    if (latitude !== null && longitude !== null) {
      return { latitude, longitude };
    }
  }

  return null;
}

function coordinateFromOsm(element: OsmElement): {
  latitude: number;
  longitude: number;
} | null {
  const direct = coordinate({ lat: element.lat, lon: element.lon });
  if (direct) return direct;
  return coordinate(element.center);
}

function normalizeName(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/\b(parking|parkings|parc|p\+r|pr)\b/g, " ")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function namesMatch(left: string, right: string): boolean {
  const a = normalizeName(left);
  const b = normalizeName(right);
  if (!a || !b) return false;
  if (a === b) return true;
  if (a.length >= 5 && b.length >= 5 && (a.includes(b) || b.includes(a))) {
    return true;
  }

  const leftTokens = new Set(a.split(" ").filter((item) => item.length > 2));
  const rightTokens = new Set(b.split(" ").filter((item) => item.length > 2));
  let common = 0;

  for (const token of leftTokens) {
    if (rightTokens.has(token)) common += 1;
  }

  return common > 0 &&
    common / Math.min(leftTokens.size, rightTokens.size) >= 0.67;
}

function dateOrNull(value: unknown): string | null {
  const text = asString(value);
  if (!text) return null;

  const direct = new Date(text);
  if (!Number.isNaN(direct.getTime())) return direct.toISOString();

  const french = text.match(
    /^(\d{2})[\/.-](\d{2})[\/.-](\d{4})\s+(\d{2}):(\d{2})/,
  );

  if (!french) return null;

  const parsed = new Date(
    `${french[3]}-${french[2]}-${french[1]}T${french[4]}:${french[5]}:00+02:00`,
  );

  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function confidence(
  updatedAt: string | null,
  maxAgeMinutes: number,
): ParkingConfidence {
  if (!updatedAt) return "official_realtime";
  const age = Date.now() - new Date(updatedAt).getTime();
  if (!Number.isFinite(age) || age < 0) return "official_realtime";
  return age <= maxAgeMinutes * 60_000
    ? "official_realtime"
    : "official_stale";
}

function officialType(value: unknown): string {
  const text = (asString(value) ?? "").toLowerCase();
  if (text.includes("souterrain")) return "underground";
  if (
    text.includes("élévation") ||
    text.includes("elevation") ||
    text.includes("étage") ||
    text.includes("ouvrage")
  ) return "multi-storey";
  if (text.includes("surface") || text.includes("enclos")) return "surface";
  return "unknown";
}

function feeFromText(value: unknown): "free" | "paid" | "unknown" {
  const text = (asString(value) ?? "").toLowerCase();
  if (text.includes("gratuit")) return "free";
  if (text.includes("payant") || text.includes("tarif") || text.includes("€")) {
    return "paid";
  }
  return "unknown";
}

function emptyParking(input: {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  distanceKm: number;
}): ParkingResult {
  return {
    parking_id: input.id,
    name: input.name,
    address: "",
    latitude: input.latitude,
    longitude: input.longitude,
    distance_km: input.distanceKm,
    parking_type: "unknown",
    access: "yes",
    fee: "unknown",
    charge: null,
    capacity: null,
    available_spaces: null,
    predicted_available_spaces: null,
    prediction_samples: null,
    disabled_spaces: null,
    charging_spaces: null,
    park_and_ride: false,
    covered: false,
    opening_hours: null,
    operator: null,
    website: null,
    phone: null,
    max_height_m: null,
    surface: null,
    source_kind: "official",
    availability_status: "unknown",
    realtime: false,
    confidence: "official_static",
    availability_updated_at: null,
    availability_source: null,
    provider_code: null,
    external_id: null,
    smart_score: 0,
    recommendation_rank: 0,
    recommendation_reasons: [],
  };
}

function inBox(
  latitude: number,
  longitude: number,
  radiusKm: number,
  minLat: number,
  maxLat: number,
  minLon: number,
  maxLon: number,
): boolean {
  const latMargin = radiusKm / 110.574;
  const lonMargin = radiusKm /
    (111.320 * Math.max(0.2, Math.cos(latitude * Math.PI / 180)));
  return latitude >= minLat - latMargin &&
    latitude <= maxLat + latMargin &&
    longitude >= minLon - lonMargin &&
    longitude <= maxLon + lonMargin;
}

async function fetchJson(url: string): Promise<JsonMap> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 18_000);

  try {
    const response = await fetch(url, {
      headers: {
        Accept: "application/json",
        "User-Agent": "AutoClair-Mobile/0.2 parking-intelligence",
      },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`HTTP_${response.status}`);
    const payload = await response.json();
    if (!isRecord(payload)) throw new Error("INVALID_JSON_RESPONSE");
    return payload;
  } finally {
    clearTimeout(timeout);
  }
}

function records(payload: JsonMap): JsonMap[] {
  return Array.isArray(payload.results)
    ? payload.results.filter(isRecord)
    : [];
}

function within(result: ParkingResult, radiusKm: number): boolean {
  return result.distance_km <= radiusKm + 0.05;
}

async function fetchDijon(
  originLat: number,
  originLon: number,
  radiusKm: number,
): Promise<ParkingResult[]> {
  const payload = await fetchJson(DIJON_ENDPOINT);
  const output: ParkingResult[] = [];

  for (const row of records(payload)) {
    const point = coordinate(row.geo_point_2d);
    if (!point) continue;

    const name = asString(row.nom_du_parking) ?? "Parking DiviaPark";
    const externalId =
      asString(row.identifiant_parking) ??
      normalizeName(name).replace(/\s+/g, "-");
    const distanceKm = Number(
      haversineKm(originLat, originLon, point.latitude, point.longitude)
        .toFixed(3),
    );
    const available = parseInteger(row.nombre_de_places_libres);
    const capacity = parseInteger(row.nombre_de_places_totales);
    const updatedAt = dateOrNull(row.derniere_mise_a_jour);
    const type = officialType(row.type_de_parking);
    const result = emptyParking({
      id: `official:dijon_diviapark:${externalId}`,
      name,
      latitude: point.latitude,
      longitude: point.longitude,
      distanceKm,
    });

    Object.assign(result, {
      address: asString(row.adresse) ?? "",
      parking_type: type,
      fee: "paid",
      capacity,
      available_spaces: available,
      disabled_spaces: parseInteger(row.places_pmr),
      charging_spaces: parseInteger(row.places_vehicules_electriques),
      covered: ["underground", "multi-storey"].includes(type),
      operator: "DiviaPark",
      availability_status: available !== null && available <= 0
        ? "full"
        : "open",
      realtime: true,
      confidence: confidence(updatedAt, 15),
      availability_updated_at: updatedAt,
      availability_source: "Dijon Métropole / DiviaPark",
      provider_code: "dijon_diviapark",
      external_id: externalId,
    });

    if (within(result, radiusKm)) output.push(result);
  }

  return output;
}

function nantesStatus(
  status: number | null,
  available: number | null,
  completeThreshold: number | null,
): ParkingStatus {
  if (status === 0) return "unavailable";
  if (status === 1 || status === 2) return "closed";
  if (
    status === 5 &&
    available !== null &&
    completeThreshold !== null &&
    available <= completeThreshold
  ) return "full";
  if (status === 5) return "open";
  return "unknown";
}

async function fetchNantes(
  originLat: number,
  originLon: number,
  radiusKm: number,
): Promise<ParkingResult[]> {
  const [staticPayload, realtimePayload, prPayload] = await Promise.all([
    fetchJson(NANTES_STATIC_ENDPOINT),
    fetchJson(NANTES_REALTIME_ENDPOINT),
    fetchJson(NANTES_PR_ENDPOINT),
  ]);

  const staticRows = records(staticPayload);
  const output: ParkingResult[] = [];

  for (const row of records(realtimePayload)) {
    const realtimeName = asString(row.grp_nom) ?? "";
    const details = staticRows.find((item) =>
      namesMatch(asString(item.nom_complet) ?? "", realtimeName)
    );
    if (!details) continue;

    const point = coordinate(details.location) ??
      coordinate({
        lat: details.lat_wgs84,
        lon: details.long_wgs84,
      });
    if (!point) continue;

    const name = asString(details.nom_complet) || realtimeName;
    const externalId =
      asString(row.grp_identifiant) ??
      asString(details.idobj) ??
      normalizeName(name).replace(/\s+/g, "-");
    const distanceKm = Number(
      haversineKm(originLat, originLon, point.latitude, point.longitude)
        .toFixed(3),
    );
    const available = parseInteger(row.grp_disponible);
    const capacity =
      parseInteger(row.grp_exploitation) ??
      parseInteger(details.capacite_voiture);
    const updatedAt = dateOrNull(row.grp_horodatage);
    const type = officialType(
      asString(details.libtype) ?? asString(details.libcategorie),
    );
    const result = emptyParking({
      id: `official:nantes_naolib:${externalId}`,
      name,
      latitude: point.latitude,
      longitude: point.longitude,
      distanceKm,
    });

    Object.assign(result, {
      address: [
        asString(details.adresse),
        asString(details.code_postal),
        asString(details.commune),
      ].filter(Boolean).join(", "),
      parking_type: type,
      fee: feeFromText(
        asString(details.infos_complementaires) ??
          asString(details.presentation),
      ),
      capacity,
      available_spaces: available,
      disabled_spaces: parseInteger(details.capacite_pmr),
      charging_spaces: parseInteger(
        details.capacite_vehicule_electrique,
      ),
      covered: ["underground", "multi-storey"].includes(type),
      operator: asString(details.exploitant) ?? "Naolib",
      website: asString(details.site_web),
      phone: asString(details.telephone),
      availability_status: nantesStatus(
        parseInteger(row.grp_statut),
        available,
        parseInteger(row.grp_complet),
      ),
      realtime: true,
      confidence: confidence(updatedAt, 15),
      availability_updated_at: updatedAt,
      availability_source: "Nantes Métropole / Naolib",
      provider_code: "nantes_naolib",
      external_id: externalId,
    });

    if (within(result, radiusKm)) output.push(result);
  }

  for (const row of records(prPayload)) {
    const point = coordinate(row.location);
    if (!point) continue;
    const name =
      asString(row.nom_complet) ??
      asString(row.grp_nom) ??
      "Parc relais Naolib";
    const externalId =
      asString(row.grp_identifiant) ??
      asString(row.idobj) ??
      normalizeName(name).replace(/\s+/g, "-");
    const distanceKm = Number(
      haversineKm(originLat, originLon, point.latitude, point.longitude)
        .toFixed(3),
    );
    const available = parseInteger(row.grp_disponible);
    const updatedAt = dateOrNull(row.grp_horodatage);
    const result = emptyParking({
      id: `official:nantes_pr:${externalId}`,
      name,
      latitude: point.latitude,
      longitude: point.longitude,
      distanceKm,
    });

    Object.assign(result, {
      address: asString(row.adresse) ?? "",
      parking_type: "surface",
      capacity: parseInteger(row.grp_exploitation),
      available_spaces: available,
      park_and_ride: true,
      operator: "Naolib",
      availability_status: nantesStatus(
        parseInteger(row.grp_statut),
        available,
        parseInteger(row.grp_complet),
      ),
      realtime: true,
      confidence: confidence(updatedAt, 15),
      availability_updated_at: updatedAt,
      availability_source: "Nantes Métropole / Naolib P+R",
      provider_code: "nantes_pr",
      external_id: externalId,
    });

    if (within(result, radiusKm)) output.push(result);
  }

  return output;
}

function strasbourgStatus(value: number | null): ParkingStatus {
  if (value === 0) return "unavailable";
  if (value === 1) return "open";
  if (value === 2) return "closed";
  if (value === 3) return "full";
  return "unknown";
}

async function fetchStrasbourg(
  originLat: number,
  originLon: number,
  radiusKm: number,
): Promise<ParkingResult[]> {
  const [staticPayload, realtimePayload] = await Promise.all([
    fetchJson(STRASBOURG_STATIC_ENDPOINT),
    fetchJson(STRASBOURG_REALTIME_ENDPOINT),
  ]);

  const staticRows = records(staticPayload);
  const output: ParkingResult[] = [];
  const fetchedAt = new Date().toISOString();

  for (const row of records(realtimePayload)) {
    const idsurfs = asString(row.idsurfs);
    const realtimeName = asString(row.nom_parking) ?? "";
    const details = staticRows.find((item) =>
      (idsurfs && asString(item.idsurfs) === idsurfs) ||
      namesMatch(asString(item.name) ?? "", realtimeName)
    );
    if (!details) continue;

    const point = coordinate(details.position) ??
      coordinate(details.geo_point_2d);
    if (!point) continue;

    const name = asString(details.name) || realtimeName;
    const externalId =
      idsurfs ??
      asString(row.ident) ??
      normalizeName(name).replace(/\s+/g, "-");
    const distanceKm = Number(
      haversineKm(originLat, originLon, point.latitude, point.longitude)
        .toFixed(3),
    );
    const normalized = normalizeName(name);
    const parkRide = [
      "hoenheim",
      "baggersee",
      "rotonde",
      "elsau",
      "poteries",
    ].some((value) => normalized.includes(value));

    const result = emptyParking({
      id: `official:strasbourg:${externalId}`,
      name,
      latitude: point.latitude,
      longitude: point.longitude,
      distanceKm,
    });

    Object.assign(result, {
      capacity: parseInteger(row.total),
      available_spaces:
        parseInteger(row.libre) ??
        parseInteger(row.infoappli),
      park_and_ride: parkRide,
      covered: !parkRide,
      website: asString(details.websiteurl),
      availability_status: strasbourgStatus(parseInteger(row.etat)),
      realtime: true,
      confidence: confidence(fetchedAt, 12),
      availability_updated_at: fetchedAt,
      availability_source: "Eurométropole de Strasbourg",
      provider_code: "strasbourg_eurometropole",
      external_id: externalId,
    });

    if (within(result, radiusKm)) output.push(result);
  }

  return output;
}

const PROVIDERS: OfficialProvider[] = [
  {
    code: "dijon_diviapark",
    name: "Dijon Métropole / DiviaPark",
    covers: (lat, lon, radius) =>
      inBox(lat, lon, radius, 47.18, 47.43, 4.88, 5.20),
    fetch: fetchDijon,
  },
  {
    code: "nantes_naolib",
    name: "Nantes Métropole / Naolib",
    covers: (lat, lon, radius) =>
      inBox(lat, lon, radius, 47.05, 47.35, -1.72, -1.38),
    fetch: fetchNantes,
  },
  {
    code: "strasbourg_eurometropole",
    name: "Eurométropole de Strasbourg",
    covers: (lat, lon, radius) =>
      inBox(lat, lon, radius, 48.43, 48.72, 7.55, 7.90),
    fetch: fetchStrasbourg,
  },
];

export async function fetchOfficialProviders(
  latitude: number,
  longitude: number,
  radiusKm: number,
): Promise<ProviderFetchResult> {
  const applicable = PROVIDERS.filter((provider) =>
    provider.covers(latitude, longitude, radiusKm)
  );

  const summaries: ProviderSummary[] = PROVIDERS
    .filter((provider) => !applicable.includes(provider))
    .map((provider) => ({
      code: provider.code,
      name: provider.name,
      status: "skipped",
      records: 0,
      realtime: true,
    }));

  const settled = await Promise.allSettled(
    applicable.map(async (provider) => ({
      provider,
      rows: await provider.fetch(latitude, longitude, radiusKm),
    })),
  );

  const output: ParkingResult[] = [];

  settled.forEach((item, index) => {
    const provider = applicable[index];

    if (item.status === "fulfilled") {
      output.push(...item.value.rows);
      summaries.push({
        code: provider.code,
        name: provider.name,
        status: "ok",
        records: item.value.rows.length,
        realtime: true,
      });
    } else {
      summaries.push({
        code: provider.code,
        name: provider.name,
        status: "error",
        records: 0,
        realtime: true,
        message: safeError(item.reason),
      });
    }
  });

  return { results: output, summaries };
}

function osmFee(tags: JsonMap): "free" | "paid" | "unknown" {
  const fee = (asString(tags.fee) ?? "").toLowerCase();
  if (["no", "0", "free"].includes(fee)) return "free";
  if (["yes", "1", "paid"].includes(fee) || asString(tags.charge)) {
    return "paid";
  }
  return "unknown";
}

function osmAddress(tags: JsonMap): string {
  const line = [
    asString(tags["addr:housenumber"]),
    asString(tags["addr:street"]),
  ].filter(Boolean).join(" ");
  const city = [
    asString(tags["addr:postcode"]),
    asString(tags["addr:city"]) ?? asString(tags["addr:town"]),
  ].filter(Boolean).join(" ");
  return [line, city].filter(Boolean).join(", ");
}

function osmParking(element: OsmElement, originLat: number, originLon: number) {
  if (!isRecord(element.tags)) return null;
  const tags = element.tags;
  const point = coordinateFromOsm(element);
  if (!point) return null;

  const access = (
    asString(tags.access) ??
    asString(tags.motorcar) ??
    asString(tags.vehicle) ??
    "unknown"
  ).toLowerCase();

  if (["private", "no", "residents", "permit"].includes(access)) return null;

  const sourceKind = asString(tags.amenity) === "parking_entrance"
    ? "entrance"
    : "facility";
  const name =
    asString(tags.name) ??
    asString(tags["name:fr"]) ??
    asString(tags.operator) ??
    "";
  const type = (
    asString(tags.parking) ??
    asString(tags.location) ??
    "unknown"
  ).toLowerCase();
  const result = emptyParking({
    id: `${asString(element.type) ?? "element"}-${String(element.id)}`,
    name,
    latitude: point.latitude,
    longitude: point.longitude,
    distanceKm: Number(
      haversineKm(originLat, originLon, point.latitude, point.longitude)
        .toFixed(3),
    ),
  });

  Object.assign(result, {
    address: osmAddress(tags),
    parking_type: type,
    access,
    fee: osmFee(tags),
    charge: asString(tags.charge),
    capacity:
      parseInteger(tags.capacity) ??
      parseInteger(tags["capacity:car"]),
    disabled_spaces:
      parseInteger(tags["capacity:disabled"]) ??
      parseInteger(tags["capacity:handicapped"]),
    charging_spaces:
      parseInteger(tags["capacity:charging"]) ??
      parseInteger(tags["capacity:charging_station"]),
    park_and_ride: Boolean(
      asString(tags.park_ride) &&
      asString(tags.park_ride)?.toLowerCase() !== "no"
    ),
    covered:
      asString(tags.covered)?.toLowerCase() === "yes" ||
      ["underground", "multi-storey", "rooftop", "carports"].includes(type),
    opening_hours: asString(tags.opening_hours),
    operator: asString(tags.operator),
    website:
      asString(tags.website) ??
      asString(tags["contact:website"]),
    phone:
      asString(tags.phone) ??
      asString(tags["contact:phone"]),
    max_height_m: parseHeight(tags.maxheight),
    surface: asString(tags.surface),
    source_kind: sourceKind,
    confidence: "osm",
  });

  return result;
}

function overpassQuery(lat: number, lon: number, radiusMeters: number) {
  return `
[out:json][timeout:20];
(
  nwr(around:${radiusMeters},${lat},${lon})["amenity"="parking"];
  node(around:${radiusMeters},${lat},${lon})["amenity"="parking_entrance"];
);
out center tags;
`.trim();
}

export async function fetchOsm(
  latitude: number,
  longitude: number,
  radiusKm: number,
): Promise<{ results: ParkingResult[]; osmBase: string | null }> {
  const query = overpassQuery(
    latitude,
    longitude,
    Math.round(radiusKm * 1000),
  );
  let lastError = "UNKNOWN";

  for (const endpoint of OVERPASS_ENDPOINTS) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 22_000);

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type":
            "application/x-www-form-urlencoded;charset=UTF-8",
          Accept: "application/json",
          "User-Agent": "AutoClair-Mobile/0.2 parking-intelligence",
        },
        body: `data=${encodeURIComponent(query)}`,
        signal: controller.signal,
      });

      if (!response.ok) {
        lastError = `HTTP_${response.status}`;
        continue;
      }

      const payload = await response.json();
      if (!isRecord(payload) || !Array.isArray(payload.elements)) {
        lastError = "INVALID_RESPONSE";
        continue;
      }

      const results = payload.elements
        .filter(isRecord)
        .map((item) =>
          osmParking(item as OsmElement, latitude, longitude)
        )
        .filter((item): item is ParkingResult => item !== null);

      const osm3s = isRecord(payload.osm3s) ? payload.osm3s : {};
      return {
        results,
        osmBase: asString(osm3s.timestamp_osm_base),
      };
    } catch (error) {
      lastError = safeError(error);
    } finally {
      clearTimeout(timeout);
    }
  }

  throw new Error(`PARKING_SOURCE_UNAVAILABLE:${lastError}`);
}

export function mergeSources(
  official: ParkingResult[],
  osm: ParkingResult[],
): ParkingResult[] {
  const output = [...official];

  for (const candidate of osm) {
    const duplicate = official.some((source) => {
      const distance = haversineKm(
        source.latitude,
        source.longitude,
        candidate.latitude,
        candidate.longitude,
      );
      if (distance > 0.18) return false;
      if (!source.name || !candidate.name) return distance <= 0.07;
      return namesMatch(source.name, candidate.name);
    });

    if (!duplicate) output.push(candidate);
  }

  return output;
}
