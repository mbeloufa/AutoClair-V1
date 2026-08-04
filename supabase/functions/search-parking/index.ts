import { authenticate } from "../_shared/auth.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  asBoolean,
  asInteger,
  asNumber,
  asString,
  isRecord,
  readJsonBody,
  safeError,
  type JsonMap,
} from "../_shared/utils.ts";

type CacheEntry = {
  expiresAt: number;
  payload: JsonMap;
};

type OsmElement = JsonMap & {
  type?: unknown;
  id?: unknown;
  lat?: unknown;
  lon?: unknown;
  center?: unknown;
  tags?: unknown;
};

type ParkingResult = {
  parking_id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  distance_km: number;
  parking_type: string;
  access: string;
  fee: "free" | "paid" | "unknown";
  charge: string | null;
  capacity: number | null;
  disabled_spaces: number | null;
  charging_spaces: number | null;
  park_and_ride: boolean;
  covered: boolean;
  opening_hours: string | null;
  operator: string | null;
  website: string | null;
  phone: string | null;
  max_height_m: number | null;
  surface: string | null;
  source_kind: "facility" | "entrance";
};

const CACHE_TTL_MS = 5 * 60 * 1000;
const MAX_RADIUS_KM = 20;
const MAX_RESULTS = 100;
const cache = new Map<string, CacheEntry>();

const OVERPASS_ENDPOINTS = [
  "https://overpass-api.de/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
];

function statusForError(message: string): number {
  if (
    message === "AUTHENTICATION_REQUIRED" ||
    message === "INVALID_OR_EXPIRED_TOKEN"
  ) return 401;
  if (
    message === "INVALID_JSON_BODY" ||
    message === "INVALID_COORDINATES" ||
    message === "INVALID_RADIUS" ||
    message === "INVALID_FILTER" ||
    message === "INVALID_SORT"
  ) return 400;
  if (message === "PARKING_SOURCE_UNAVAILABLE") return 503;
  return 500;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function normalizeEnum(
  value: unknown,
  allowed: string[],
  fallback: string,
  errorCode: string,
): string {
  const normalized = (asString(value) ?? fallback).toLowerCase();
  if (!allowed.includes(normalized)) throw new Error(errorCode);
  return normalized;
}

function parseInteger(value: unknown): number | null {
  const parsed = asInteger(value);
  if (parsed !== null && parsed >= 0) return parsed;

  const text = asString(value);
  if (!text) return null;
  const match = text.match(/\d+/);
  return match ? Number(match[0]) : null;
}

function parseHeightMeters(value: unknown): number | null {
  const text = asString(value);
  if (!text) return null;

  const metric = text
    .toLowerCase()
    .replace(",", ".")
    .match(/(\d+(?:\.\d+)?)\s*(?:m|meter|metre)?/);
  if (!metric) return null;

  const parsed = Number(metric[1]);
  return Number.isFinite(parsed) && parsed > 0 && parsed < 10
    ? parsed
    : null;
}

function normalizeFee(tags: JsonMap): "free" | "paid" | "unknown" {
  const fee = (asString(tags.fee) ?? "").toLowerCase();
  if (["no", "0", "free"].includes(fee)) return "free";
  if (["yes", "1", "paid"].includes(fee)) return "paid";
  if (asString(tags.charge)) return "paid";
  return "unknown";
}

function normalizeAccess(tags: JsonMap): string {
  const access = (
    asString(tags.access) ??
    asString(tags.motorcar) ??
    asString(tags.vehicle) ??
    "unknown"
  ).toLowerCase();

  return access;
}

function isExcludedAccess(access: string): boolean {
  return [
    "private",
    "no",
    "residents",
    "permit",
    "delivery",
    "agricultural",
    "forestry",
  ].includes(access);
}

function coordinateFor(element: OsmElement): {
  latitude: number;
  longitude: number;
} | null {
  const lat = asNumber(element.lat);
  const lon = asNumber(element.lon);
  if (lat !== null && lon !== null) {
    return { latitude: lat, longitude: lon };
  }

  if (isRecord(element.center)) {
    const centerLat = asNumber(element.center.lat);
    const centerLon = asNumber(element.center.lon);
    if (centerLat !== null && centerLon !== null) {
      return { latitude: centerLat, longitude: centerLon };
    }
  }

  return null;
}

function haversineKm(
  latitude1: number,
  longitude1: number,
  latitude2: number,
  longitude2: number,
): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const earthRadiusKm = 6371.0088;
  const deltaLatitude = radians(latitude2 - latitude1);
  const deltaLongitude = radians(longitude2 - longitude1);
  const lat1 = radians(latitude1);
  const lat2 = radians(latitude2);

  const value =
    Math.sin(deltaLatitude / 2) ** 2 +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(deltaLongitude / 2) ** 2;

  return 2 * earthRadiusKm * Math.asin(Math.sqrt(value));
}

function addressFromTags(tags: JsonMap): string {
  const line = [
    asString(tags["addr:housenumber"]),
    asString(tags["addr:street"]),
  ].filter(Boolean).join(" ");

  const locality = [
    asString(tags["addr:postcode"]),
    asString(tags["addr:city"]) ??
      asString(tags["addr:town"]) ??
      asString(tags["addr:village"]),
  ].filter(Boolean).join(" ");

  return [line, locality].filter(Boolean).join(", ");
}

function parkingType(tags: JsonMap): string {
  return (
    asString(tags.parking) ??
    asString(tags.location) ??
    "unknown"
  ).toLowerCase();
}

function isCovered(type: string, tags: JsonMap): boolean {
  if (asString(tags.covered)?.toLowerCase() === "yes") return true;
  return [
    "underground",
    "multi-storey",
    "rooftop",
    "carports",
    "garage_boxes",
  ].includes(type);
}

function parkAndRide(tags: JsonMap): boolean {
  const value = (asString(tags.park_ride) ?? "").toLowerCase();
  return Boolean(value && !["no", "false", "0"].includes(value));
}

function buildResult(
  element: OsmElement,
  originLatitude: number,
  originLongitude: number,
): ParkingResult | null {
  if (!isRecord(element.tags)) return null;
  const tags = element.tags;
  const coordinate = coordinateFor(element);
  if (!coordinate) return null;

  const access = normalizeAccess(tags);
  if (isExcludedAccess(access)) return null;

  const type = parkingType(tags);
  const sourceKind = asString(tags.amenity) === "parking_entrance"
    ? "entrance"
    : "facility";

  const name =
    asString(tags.name) ??
    asString(tags["name:fr"]) ??
    asString(tags.operator) ??
    "";

  const disabledSpaces =
    parseInteger(tags["capacity:disabled"]) ??
    parseInteger(tags["capacity:handicapped"]);

  const chargingSpaces =
    parseInteger(tags["capacity:charging"]) ??
    parseInteger(tags["capacity:charging_station"]) ??
    (
      ["yes", "designated"].includes(
        (asString(tags.charging_station) ?? "").toLowerCase(),
      )
        ? 1
        : null
    );

  const id = `${asString(element.type) ?? "element"}-${String(element.id)}`;

  return {
    parking_id: id,
    name,
    address: addressFromTags(tags),
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
    distance_km: Number(
      haversineKm(
        originLatitude,
        originLongitude,
        coordinate.latitude,
        coordinate.longitude,
      ).toFixed(3),
    ),
    parking_type: type,
    access,
    fee: normalizeFee(tags),
    charge: asString(tags.charge),
    capacity:
      parseInteger(tags.capacity) ??
      parseInteger(tags["capacity:car"]),
    disabled_spaces: disabledSpaces,
    charging_spaces: chargingSpaces,
    park_and_ride: parkAndRide(tags),
    covered: isCovered(type, tags),
    opening_hours: asString(tags.opening_hours),
    operator: asString(tags.operator),
    website:
      asString(tags.website) ??
      asString(tags["contact:website"]),
    phone:
      asString(tags.phone) ??
      asString(tags["contact:phone"]),
    max_height_m: parseHeightMeters(tags.maxheight),
    surface: asString(tags.surface),
    source_kind: sourceKind,
  };
}

function matchesType(result: ParkingResult, filter: string): boolean {
  if (filter === "all") return true;
  if (filter === "park_and_ride") return result.park_and_ride;
  if (filter === "covered") return result.covered;
  if (filter === "surface") return result.parking_type === "surface";
  if (filter === "street") {
    return [
      "street_side",
      "lane",
      "on_street",
      "on_kerb",
      "half_on_kerb",
    ].includes(result.parking_type);
  }
  return true;
}

function deduplicate(results: ParkingResult[]): ParkingResult[] {
  const facilities = results.filter((item) => item.source_kind === "facility");
  const output = [...facilities];

  for (const entrance of results.filter(
    (item) => item.source_kind === "entrance",
  )) {
    const duplicate = facilities.some((facility) => {
      const close = haversineKm(
        facility.latitude,
        facility.longitude,
        entrance.latitude,
        entrance.longitude,
      ) <= 0.08;

      const sameName = Boolean(
        facility.name &&
        entrance.name &&
        facility.name.toLowerCase() === entrance.name.toLowerCase(),
      );

      return close && (sameName || !entrance.name);
    });

    if (!duplicate) output.push(entrance);
  }

  return output;
}

function sortResults(
  results: ParkingResult[],
  sortBy: string,
): ParkingResult[] {
  return results.slice().sort((a, b) => {
    if (sortBy === "capacity") {
      const capacityA = a.capacity ?? -1;
      const capacityB = b.capacity ?? -1;
      if (capacityA !== capacityB) return capacityB - capacityA;
    }

    if (sortBy === "free") {
      const score = (item: ParkingResult) =>
        item.fee === "free" ? 0 : item.fee === "unknown" ? 1 : 2;
      const difference = score(a) - score(b);
      if (difference !== 0) return difference;
    }

    return a.distance_km - b.distance_km;
  });
}

function buildQuery(
  latitude: number,
  longitude: number,
  radiusMeters: number,
): string {
  return `
[out:json][timeout:20];
(
  nwr(around:${radiusMeters},${latitude},${longitude})
    ["amenity"="parking"];
  node(around:${radiusMeters},${latitude},${longitude})
    ["amenity"="parking_entrance"];
);
out center tags;
`.trim();
}

async function fetchOverpass(query: string): Promise<JsonMap> {
  let lastError = "UNKNOWN";

  for (const endpoint of OVERPASS_ENDPOINTS) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 22_000);

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "Accept": "application/json",
          "User-Agent": "AutoClair-Mobile/0.1 parking-search",
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

      return payload;
    } catch (error) {
      lastError = safeError(error);
    } finally {
      clearTimeout(timeout);
    }
  }

  throw new Error(`PARKING_SOURCE_UNAVAILABLE:${lastError}`);
}

function cacheKey(input: {
  latitude: number;
  longitude: number;
  radiusKm: number;
  parkingType: string;
  sortBy: string;
  freeOnly: boolean;
  accessibleOnly: boolean;
  evOnly: boolean;
  resultLimit: number;
}): string {
  return JSON.stringify({
    ...input,
    latitude: input.latitude.toFixed(3),
    longitude: input.longitude.toFixed(3),
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    await authenticate(req);
    const body = await readJsonBody(req);

    const latitude = asNumber(body.latitude);
    const longitude = asNumber(body.longitude);
    const radiusKm = asNumber(body.radius_km) ?? 5;

    if (
      latitude === null ||
      longitude === null ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      throw new Error("INVALID_COORDINATES");
    }

    if (radiusKm <= 0 || radiusKm > MAX_RADIUS_KM) {
      throw new Error("INVALID_RADIUS");
    }

    const parkingType = normalizeEnum(
      body.parking_type,
      ["all", "covered", "surface", "street", "park_and_ride"],
      "all",
      "INVALID_FILTER",
    );

    const sortBy = normalizeEnum(
      body.sort_by,
      ["distance", "capacity", "free"],
      "distance",
      "INVALID_SORT",
    );

    const freeOnly = asBoolean(body.free_only);
    const accessibleOnly = asBoolean(body.accessible_only);
    const evOnly = asBoolean(body.ev_only);
    const resultLimit = clamp(
      asInteger(body.result_limit) ?? 80,
      1,
      MAX_RESULTS,
    );

    const input = {
      latitude,
      longitude,
      radiusKm,
      parkingType,
      sortBy,
      freeOnly,
      accessibleOnly,
      evOnly,
      resultLimit,
    };

    const key = cacheKey(input);
    const cached = cache.get(key);
    if (cached && cached.expiresAt > Date.now()) {
      return jsonResponse({
        ...cached.payload,
        cache_hit: true,
      });
    }

    const query = buildQuery(
      latitude,
      longitude,
      Math.round(radiusKm * 1000),
    );
    const payload = await fetchOverpass(query);
    const elements = payload.elements as unknown[];

    let results = elements
      .filter(isRecord)
      .map((element) =>
        buildResult(element as OsmElement, latitude, longitude)
      )
      .filter((item): item is ParkingResult => item !== null);

    results = deduplicate(results).filter((item) => {
      if (item.distance_km > radiusKm + 0.05) return false;
      if (!matchesType(item, parkingType)) return false;
      if (freeOnly && item.fee !== "free") return false;
      if (accessibleOnly && (item.disabled_spaces ?? 0) < 1) return false;
      if (evOnly && (item.charging_spaces ?? 0) < 1) return false;
      return true;
    });

    results = sortResults(results, sortBy);
    const truncated = results.length > resultLimit;
    results = results.slice(0, resultLimit);

    const osm3s = isRecord(payload.osm3s) ? payload.osm3s : {};
    const sourceFetchedAt = new Date().toISOString();

    const responsePayload: JsonMap = {
      success: true,
      results,
      source_name: "OpenStreetMap via Overpass",
      source_fetched_at: sourceFetchedAt,
      osm_base: asString(osm3s.timestamp_osm_base),
      cache_hit: false,
      truncated,
      availability_disclaimer:
        "La source ne fournit généralement pas le nombre de places libres en temps réel. La capacité affichée est une capacité déclarée, pas une disponibilité.",
    };

    cache.set(key, {
      expiresAt: Date.now() + CACHE_TTL_MS,
      payload: responsePayload,
    });

    if (cache.size > 120) {
      for (const [cacheKeyValue, entry] of cache.entries()) {
        if (entry.expiresAt <= Date.now()) cache.delete(cacheKeyValue);
      }
    }

    return jsonResponse(responsePayload);
  } catch (error) {
    const message = safeError(error);
    const code = message.split(":")[0];

    return jsonResponse({
      success: false,
      error: code,
      message: code === "PARKING_SOURCE_UNAVAILABLE"
        ? "La source cartographique des parkings est momentanément indisponible."
        : message,
    }, statusForError(code));
  }
});
