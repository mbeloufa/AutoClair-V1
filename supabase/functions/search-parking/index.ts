import {
  authenticate,
  type AuthContext,
} from "../_shared/auth.ts";
import {
  corsHeaders,
  jsonResponse,
} from "../_shared/cors.ts";
import {
  asBoolean,
  asInteger,
  asNumber,
  asString,
  clamp,
  readJsonBody,
  safeError,
  sha256Hex,
  type JsonMap,
} from "../_shared/utils.ts";
import {
  fetchOfficialProviders,
  fetchOsm,
  haversineKm,
  mergeSources,
} from "./providers.ts";
import {
  type ParkingResult,
  type Prediction,
  type ProviderSummary,
} from "./types.ts";

type CacheEntry = {
  expiresAt: number;
  payload: JsonMap;
};

const CACHE_TTL_MS = 3 * 60 * 1000;
const MAX_RADIUS_KM = 20;
const MAX_RESULTS = 100;
const cache = new Map<string, CacheEntry>();

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
    message === "INVALID_SORT" ||
    message === "INVALID_PREFERENCE" ||
    message === "INVALID_ARRIVAL"
  ) return 400;

  if (message === "PARKING_SOURCE_UNAVAILABLE") return 503;
  return 500;
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

function deduplicateOsm(results: ParkingResult[]): ParkingResult[] {
  const facilities = results.filter(
    (item) => item.source_kind === "facility",
  );
  const output = [...facilities];

  for (const entrance of results.filter(
    (item) => item.source_kind === "entrance",
  )) {
    const duplicate = facilities.some((facility) =>
      haversineKm(
        facility.latitude,
        facility.longitude,
        entrance.latitude,
        entrance.longitude,
      ) <= 0.07
    );

    if (!duplicate) output.push(entrance);
  }

  return output;
}

async function storeSnapshots(
  auth: AuthContext,
  results: ParkingResult[],
): Promise<boolean> {
  const observedAt = new Date().toISOString();
  const rows: JsonMap[] = [];

  for (const result of results) {
    if (
      !result.provider_code ||
      !result.external_id ||
      !result.realtime
    ) continue;

    const sourceUpdatedAt =
      result.availability_updated_at ??
      observedAt;

    rows.push({
      provider_code: result.provider_code,
      external_id: result.external_id,
      parking_name: result.name,
      latitude: result.latitude,
      longitude: result.longitude,
      available_spaces: result.available_spaces,
      capacity: result.capacity,
      availability_status: result.availability_status,
      source_updated_at: sourceUpdatedAt,
      observed_at: observedAt,
      source_hash: await sha256Hex({
        provider_code: result.provider_code,
        external_id: result.external_id,
        available_spaces: result.available_spaces,
        capacity: result.capacity,
        availability_status: result.availability_status,
        source_updated_at: sourceUpdatedAt,
      }),
    });
  }

  if (!rows.length) return false;

  const { error } = await auth.adminClient
    .from("parking_availability_snapshots")
    .upsert(rows, {
      onConflict: "provider_code,external_id,source_updated_at",
      ignoreDuplicates: true,
    });

  if (error) {
    console.warn("PARKING_HISTORY_WRITE_FAILED", error.message);
    return false;
  }

  return true;
}

function localDateParts(
  value: Date,
  timezoneOffsetMinutes: number,
): {
  weekday: number;
  hour: number;
} {
  const local = new Date(
    value.getTime() + timezoneOffsetMinutes * 60_000,
  );

  return {
    weekday: local.getUTCDay(),
    hour: local.getUTCHours(),
  };
}

function hourDistance(left: number, right: number): number {
  const direct = Math.abs(left - right);
  return Math.min(direct, 24 - direct);
}

async function loadPredictions(
  auth: AuthContext,
  results: ParkingResult[],
  arrivalMinutes: number,
  timezoneOffsetMinutes: number,
): Promise<Map<string, Prediction>> {
  const official = results.filter(
    (item) => item.provider_code && item.external_id,
  );

  if (!official.length) return new Map();

  const externalIds = Array.from(
    new Set(official.map((item) => item.external_id!)),
  );

  const since = new Date(
    Date.now() - 56 * 86_400_000,
  ).toISOString();

  const { data, error } = await auth.adminClient
    .from("parking_availability_snapshots")
    .select(
      "provider_code,external_id,available_spaces," +
        "availability_status,observed_at",
    )
    .in("external_id", externalIds)
    .gte("observed_at", since)
    .limit(5000);

  if (error || !data) return new Map();

  const target = new Date(
    Date.now() + arrivalMinutes * 60_000,
  );
  const targetParts = localDateParts(
    target,
    timezoneOffsetMinutes,
  );
  const groups = new Map<string, number[]>();

  for (const row of data) {
    if (
      row.availability_status !== "open" ||
      typeof row.available_spaces !== "number" ||
      typeof row.provider_code !== "string" ||
      typeof row.external_id !== "string" ||
      typeof row.observed_at !== "string"
    ) continue;

    const observed = new Date(row.observed_at);
    if (Number.isNaN(observed.getTime())) continue;

    const parts = localDateParts(
      observed,
      timezoneOffsetMinutes,
    );

    if (
      parts.weekday !== targetParts.weekday ||
      hourDistance(parts.hour, targetParts.hour) > 1
    ) continue;

    const key = `${row.provider_code}:${row.external_id}`;
    const values = groups.get(key) ?? [];
    values.push(row.available_spaces);
    groups.set(key, values);
  }

  const predictions = new Map<string, Prediction>();

  for (const [key, values] of groups.entries()) {
    if (values.length < 3) continue;

    values.sort((a, b) => a - b);
    const middle = Math.floor(values.length / 2);
    const median = values.length % 2 === 0
      ? Math.round(
        (values[middle - 1] + values[middle]) / 2,
      )
      : values[middle];

    predictions.set(key, {
      available: median,
      samples: values.length,
    });
  }

  return predictions;
}

function applyPredictions(
  results: ParkingResult[],
  predictions: Map<string, Prediction>,
): void {
  for (const result of results) {
    if (!result.provider_code || !result.external_id) continue;

    const prediction = predictions.get(
      `${result.provider_code}:${result.external_id}`,
    );

    if (!prediction) continue;

    result.predicted_available_spaces = prediction.available;
    result.prediction_samples = prediction.samples;
  }
}

function ageMinutes(value: string | null): number | null {
  if (!value) return null;

  const age = Date.now() - new Date(value).getTime();
  if (!Number.isFinite(age)) return null;

  return Math.max(0, Math.round(age / 60_000));
}

function scoreParking(
  item: ParkingResult,
  preference: string,
  arrivalMinutes: number,
  radiusKm: number,
): number {
  const maxDistance = Math.max(radiusKm, 1);
  let score = clamp(
    35 * (1 - item.distance_km / maxDistance),
    0,
    35,
  );

  if (preference === "closest") {
    score += clamp(
      20 * (1 - item.distance_km / maxDistance),
      0,
      20,
    );
  }

  if (item.availability_status === "closed") score -= 45;
  if (item.availability_status === "full") score -= 40;
  if (item.availability_status === "unavailable") score -= 8;

  if (
    item.available_spaces !== null &&
    item.capacity !== null &&
    item.capacity > 0 &&
    item.availability_status === "open"
  ) {
    const ratio = clamp(
      item.available_spaces / item.capacity,
      0,
      1,
    );
    const arrivalDecay = clamp(
      1 - arrivalMinutes / 120,
      0.45,
      1,
    );
    let weight = preference === "availability" ? 46 : 34;
    weight *= arrivalDecay;

    if (item.confidence === "official_realtime") {
      score += 12 + ratio * weight;
    } else if (item.confidence === "official_stale") {
      score += 4 + ratio * 10;
    }
  } else if (item.confidence === "official_realtime") {
    score += 8;
  }

  if (
    item.predicted_available_spaces !== null &&
    item.prediction_samples !== null &&
    item.prediction_samples >= 3
  ) {
    const capacity = item.capacity ??
      Math.max(item.predicted_available_spaces, 1);

    const ratio = clamp(
      item.predicted_available_spaces /
        Math.max(capacity, 1),
      0,
      1,
    );

    score += ratio * (arrivalMinutes >= 30 ? 18 : 10);
  }

  if (item.confidence === "official_realtime") score += 8;
  if (item.confidence === "official_stale") score += 2;
  if (item.park_and_ride) score += 2;

  if ((item.charging_spaces ?? 0) > 0) {
    score += preference === "ev" ? 22 : 3;
  }

  if (item.fee === "free") {
    score += preference === "free" ? 24 : 5;
  }

  if (preference === "free" && item.fee === "paid") score -= 12;
  if (preference === "ev" && (item.charging_spaces ?? 0) < 1) {
    score -= 14;
  }

  return Number(clamp(score, 0, 100).toFixed(1));
}

function recommendationReasons(
  item: ParkingResult,
  arrivalMinutes: number,
): string[] {
  const reasons: string[] = [];

  if (
    item.availability_status === "open" &&
    item.available_spaces !== null &&
    item.confidence === "official_realtime"
  ) {
    const count = item.available_spaces;
    reasons.push(
      `${count} place${count === 1 ? "" : "s"} ` +
        `libre${count === 1 ? "" : "s"} en temps réel`,
    );
  }

  if (
    item.predicted_available_spaces !== null &&
    item.prediction_samples !== null &&
    item.prediction_samples >= 3 &&
    arrivalMinutes > 0
  ) {
    reasons.push(
      `Environ ${item.predicted_available_spaces} places ` +
        "habituellement disponibles à l’heure d’arrivée",
    );
  }

  if (item.distance_km <= 1) {
    reasons.push("À moins d’un kilomètre");
  } else if (item.distance_km <= 3) {
    reasons.push(
      `À ${item.distance_km.toFixed(1).replace(".", ",")} km`,
    );
  }

  if (item.fee === "free") {
    reasons.push("Stationnement déclaré gratuit");
  }

  if (item.park_and_ride) reasons.push("Parc relais");

  if ((item.charging_spaces ?? 0) > 0) {
    reasons.push(
      `${item.charging_spaces} places avec recharge déclarées`,
    );
  }

  const age = ageMinutes(item.availability_updated_at);

  if (age !== null && age <= 5) {
    reasons.push(
      `Donnée officielle mise à jour il y a ${age} min`,
    );
  }

  if (!reasons.length) {
    reasons.push(
      "Solution cartographiée proche de votre position",
    );
  }

  return reasons.slice(0, 4);
}

function rankResults(
  results: ParkingResult[],
  preference: string,
  arrivalMinutes: number,
  radiusKm: number,
  sortBy: string,
): ParkingResult[] {
  for (const result of results) {
    result.smart_score = scoreParking(
      result,
      preference,
      arrivalMinutes,
      radiusKm,
    );

    result.recommendation_reasons = recommendationReasons(
      result,
      arrivalMinutes,
    );
  }

  const sorted = results.slice().sort((a, b) => {
    if (sortBy === "distance") {
      return a.distance_km - b.distance_km;
    }

    if (sortBy === "capacity") {
      const capacityA = a.capacity ?? -1;
      const capacityB = b.capacity ?? -1;
      if (capacityA !== capacityB) return capacityB - capacityA;
    }

    if (sortBy === "free") {
      const feeScore = (item: ParkingResult) =>
        item.fee === "free"
          ? 0
          : item.fee === "unknown"
          ? 1
          : 2;

      const difference = feeScore(a) - feeScore(b);
      if (difference !== 0) return difference;
    }

    if (sortBy === "availability") {
      const availableA =
        a.availability_status === "open"
          ? a.available_spaces ?? -1
          : -1;

      const availableB =
        b.availability_status === "open"
          ? b.available_spaces ?? -1
          : -1;

      if (availableA !== availableB) {
        return availableB - availableA;
      }
    }

    if (a.smart_score !== b.smart_score) {
      return b.smart_score - a.smart_score;
    }

    return a.distance_km - b.distance_km;
  });

  sorted.forEach((item, index) => {
    item.recommendation_rank = index + 1;
  });

  return sorted;
}

function cacheKey(input: JsonMap): string {
  return JSON.stringify({
    ...input,
    latitude: asNumber(input.latitude)?.toFixed(3),
    longitude: asNumber(input.longitude)?.toFixed(3),
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
    const auth = await authenticate(req);
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
      [
        "recommendation",
        "availability",
        "distance",
        "capacity",
        "free",
      ],
      "recommendation",
      "INVALID_SORT",
    );

    const preference = normalizeEnum(
      body.preference,
      ["availability", "closest", "free", "ev"],
      "availability",
      "INVALID_PREFERENCE",
    );

    const arrivalMinutes = asInteger(body.arrival_minutes) ?? 15;

    if (![0, 15, 30, 60].includes(arrivalMinutes)) {
      throw new Error("INVALID_ARRIVAL");
    }

    const timezoneOffsetMinutes = clamp(
      asInteger(body.timezone_offset_minutes) ?? 0,
      -840,
      840,
    );

    const freeOnly = asBoolean(body.free_only);
    const accessibleOnly = asBoolean(body.accessible_only);
    const evOnly = asBoolean(body.ev_only);
    const resultLimit = clamp(
      asInteger(body.result_limit) ?? 80,
      1,
      MAX_RESULTS,
    );

    const input: JsonMap = {
      latitude,
      longitude,
      radiusKm,
      parkingType,
      sortBy,
      preference,
      arrivalMinutes,
      timezoneOffsetMinutes,
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

    const [osmSettlement, officialSettlement] =
      await Promise.allSettled([
        fetchOsm(latitude, longitude, radiusKm),
        fetchOfficialProviders(latitude, longitude, radiusKm),
      ]);

    const osmResults = osmSettlement.status === "fulfilled"
      ? deduplicateOsm(osmSettlement.value.results)
      : [];

    const osmBase = osmSettlement.status === "fulfilled"
      ? osmSettlement.value.osmBase
      : null;

    const officialResults =
      officialSettlement.status === "fulfilled"
        ? officialSettlement.value.results
        : [];

    const providers: ProviderSummary[] =
      officialSettlement.status === "fulfilled"
        ? officialSettlement.value.summaries
        : [{
          code: "official_providers",
          name: "Flux officiels locaux",
          status: "error",
          records: 0,
          realtime: true,
          message: safeError(officialSettlement.reason),
        }];

    if (!osmResults.length && !officialResults.length) {
      throw new Error("PARKING_SOURCE_UNAVAILABLE");
    }

    let results = mergeSources(
      officialResults,
      osmResults,
    );

    results = results.filter((item) => {
      if (item.distance_km > radiusKm + 0.05) return false;
      if (!matchesType(item, parkingType)) return false;
      if (freeOnly && item.fee !== "free") return false;
      if (
        accessibleOnly &&
        (item.disabled_spaces ?? 0) < 1
      ) return false;
      if (evOnly && (item.charging_spaces ?? 0) < 1) {
        return false;
      }
      return true;
    });

    const historyStored = await storeSnapshots(
      auth,
      officialResults,
    );

    const predictions = await loadPredictions(
      auth,
      results,
      arrivalMinutes,
      timezoneOffsetMinutes,
    );

    applyPredictions(results, predictions);

    results = rankResults(
      results,
      preference,
      arrivalMinutes,
      radiusKm,
      sortBy,
    );

    const truncated = results.length > resultLimit;
    results = results.slice(0, resultLimit);

    const realtimeCoverage = officialResults.some(
      (item) => item.confidence === "official_realtime",
    );

    const responsePayload: JsonMap = {
      success: true,
      results,
      providers,
      source_name:
        "OpenStreetMap, Dijon Métropole, Nantes Métropole " +
        "et Eurométropole de Strasbourg",
      source_fetched_at: new Date().toISOString(),
      osm_base: osmBase,
      cache_hit: false,
      truncated,
      realtime_coverage: realtimeCoverage,
      recommended_parking_id:
        results[0]?.parking_id ?? null,
      history_enabled:
        historyStored || predictions.size > 0,
      availability_disclaimer:
        "Le nombre de places libres provient des flux officiels " +
        "lorsqu’ils sont disponibles. Une donnée trop ancienne est " +
        "signalée et moins bien classée. La disponibilité peut " +
        "évoluer avant l’arrivée.",
    };

    cache.set(key, {
      expiresAt: Date.now() + CACHE_TTL_MS,
      payload: responsePayload,
    });

    if (cache.size > 120) {
      for (const [cacheKeyValue, entry] of cache.entries()) {
        if (entry.expiresAt <= Date.now()) {
          cache.delete(cacheKeyValue);
        }
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
        ? "Les sources de stationnement sont momentanément indisponibles."
        : message,
    }, statusForError(code));
  }
});
