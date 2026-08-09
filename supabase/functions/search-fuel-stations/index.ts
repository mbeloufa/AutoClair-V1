import { createClient } from "npm:@supabase/supabase-js@2";

const OFFICIAL_API_URL =
  "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records";

const PAGE_SIZE = 100;
const MAX_RECORDS = 1000;
const CACHE_DURATION_MINUTES = 10;

const FUEL_FIELDS: Record<string, string> = {
  Gazole: "gazole",
  SP95: "sp95",
  SP98: "sp98",
  E10: "e10",
  E85: "e85",
  GPLc: "gplc",
};

const RESPONSE_HEADERS = {
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
  fuel_type?: unknown;
  sort_by?: unknown;
  result_limit?: unknown;
};

type OfficialResponse = {
  total_count?: number;
  results?: Record<string, unknown>[];
};

type NormalizedStation = {
  station_id: string;
  address: string;
  postal_code: string;
  city: string;
  latitude: number;
  longitude: number;
  distance_km: number;
  fuel_type: string;
  price: number | null;
  price_updated_at: string | null;
  availability:
    | "available"
    | "temporary_outage"
    | "definitive_outage"
    | "unknown";
  outage_started_at: string | null;
  automate_24h: boolean;
  services: string[];
  source_fetched_at: string;
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: RESPONSE_HEADERS,
  });
}

function requiredNumber(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): number {
  const numberValue = typeof value === "number"
    ? value
    : Number(String(value ?? "").replace(",", "."));

  if (
    !Number.isFinite(numberValue) ||
    numberValue < minimum ||
    numberValue > maximum
  ) {
    throw new Error(
      `${field} doit être compris entre ${minimum} et ${maximum}.`,
    );
  }

  return numberValue;
}

function requiredInteger(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
  defaultValue: number,
): number {
  const numberValue = value === null || value === undefined
    ? defaultValue
    : Number(value);

  if (
    !Number.isInteger(numberValue) ||
    numberValue < minimum ||
    numberValue > maximum
  ) {
    throw new Error(
      `${field} doit être compris entre ${minimum} et ${maximum}.`,
    );
  }

  return numberValue;
}

function requiredFuelType(value: unknown): string {
  const fuelType = String(value ?? "").trim();
  if (!Object.hasOwn(FUEL_FIELDS, fuelType)) {
    throw new Error(
      "fuel_type doit être Gazole, SP95, SP98, E10, E85 ou GPLc.",
    );
  }
  return fuelType;
}

function requiredSort(value: unknown): "price" | "distance" {
  const sortBy = String(value ?? "price").trim().toLowerCase();
  if (sortBy !== "price" && sortBy !== "distance") {
    throw new Error("sort_by doit être price ou distance.");
  }
  return sortBy;
}

function text(value: unknown): string | null {
  const normalized = value?.toString().trim();
  return normalized == null || normalized.length === 0 ? null : normalized;
}

function numberOrNull(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = typeof value === "number"
    ? value
    : Number(String(value).trim().replace(",", "."));
  return Number.isFinite(parsed) ? parsed : null;
}

function isoDateOrNull(value: unknown): string | null {
  const raw = text(value);
  if (!raw) return null;

  const normalized = raw.includes("T")
    ? raw
    : `${raw.replace(" ", "T")}Z`;
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function coordinates(
  record: Record<string, unknown>,
): { latitude: number; longitude: number } | null {
  const geometry = record.geom;

  if (geometry && typeof geometry === "object") {
    const map = geometry as Record<string, unknown>;
    const latitude = numberOrNull(map.lat ?? map.latitude);
    const longitude = numberOrNull(map.lon ?? map.longitude);
    if (
      latitude !== null &&
      longitude !== null &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180
    ) {
      return { latitude, longitude };
    }
  }

  let latitude = numberOrNull(record.latitude);
  let longitude = numberOrNull(record.longitude);
  if (latitude === null || longitude === null) return null;

  if (Math.abs(latitude) > 90) latitude /= 100000;
  if (Math.abs(longitude) > 180) longitude /= 100000;

  if (
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return null;
  }

  return { latitude, longitude };
}

function stringList(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value
      .map((item) => text(item))
      .filter((item): item is string => item !== null);
  }

  const raw = text(value);
  if (!raw) return [];

  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return stringList(parsed);
    if (parsed && typeof parsed === "object") {
      return stringList((parsed as Record<string, unknown>).service);
    }
  } catch {
    // Certaines anciennes réponses utilisent une liste séparée par des virgules.
  }

  return raw
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function distanceKm(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const earthRadiusKm = 6371.0088;
  const latitudeDelta = radians(latitudeB - latitudeA);
  const longitudeDelta = radians(longitudeB - longitudeA);

  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(latitudeA)) *
      Math.cos(radians(latitudeB)) *
      Math.sin(longitudeDelta / 2) ** 2;

  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function cacheKey(
  latitude: number,
  longitude: number,
  radiusKm: number,
  fuelType: string,
): string {
  return [
    "v1",
    fuelType,
    latitude.toFixed(3),
    longitude.toFixed(3),
    radiusKm.toFixed(0),
  ].join(":");
}

function normalizeStation(
  record: Record<string, unknown>,
  latitude: number,
  longitude: number,
  radiusKm: number,
  fuelType: string,
  fieldPrefix: string,
  sourceFetchedAt: string,
): NormalizedStation | null {
  const point = coordinates(record);
  if (!point) return null;

  const distance = distanceKm(
    latitude,
    longitude,
    point.latitude,
    point.longitude,
  );
  if (distance > radiusKm + 0.2) return null;

  const price = numberOrNull(record[`${fieldPrefix}_prix`]);
  const outageType = text(record[`${fieldPrefix}_rupture_type`])
    ?.toLowerCase();
  const outageStartedAt = isoDateOrNull(
    record[`${fieldPrefix}_rupture_debut`],
  );

  if (price === null && !outageType) return null;

  const availability = outageType === "temporaire"
    ? "temporary_outage"
    : outageType === "definitive"
    ? "definitive_outage"
    : price !== null
    ? "available"
    : "unknown";

  return {
    station_id: String(record.id ?? "").trim(),
    address: text(record.adresse) ?? "",
    postal_code: text(record.cp) ?? "",
    city: text(record.ville) ?? "",
    latitude: point.latitude,
    longitude: point.longitude,
    distance_km: Math.round(distance * 100) / 100,
    fuel_type: fuelType,
    price,
    price_updated_at: isoDateOrNull(record[`${fieldPrefix}_maj`]),
    availability,
    outage_started_at: outageStartedAt,
    automate_24h:
      (text(record.horaires_automate_24_24) ?? "").toLowerCase() ===
        "oui",
    services: stringList(record.services_service ?? record.services),
    source_fetched_at: sourceFetchedAt,
  };
}

function sortStations(
  stations: NormalizedStation[],
  sortBy: "price" | "distance",
): NormalizedStation[] {
  return [...stations].sort((left, right) => {
    if (sortBy === "distance") {
      const distanceComparison = left.distance_km - right.distance_km;
      if (Math.abs(distanceComparison) > 0.0001) return distanceComparison;

      const leftPrice = left.price ?? Number.POSITIVE_INFINITY;
      const rightPrice = right.price ?? Number.POSITIVE_INFINITY;
      return leftPrice - rightPrice;
    }

    const leftAvailable = left.availability === "available" && left.price !== null;
    const rightAvailable = right.availability === "available" && right.price !== null;
    if (leftAvailable !== rightAvailable) return leftAvailable ? -1 : 1;

    const leftPrice = left.price ?? Number.POSITIVE_INFINITY;
    const rightPrice = right.price ?? Number.POSITIVE_INFINITY;
    const priceComparison = leftPrice - rightPrice;
    if (Math.abs(priceComparison) > 0.000001) return priceComparison;

    return left.distance_km - right.distance_km;
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: RESPONSE_HEADERS });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      { success: false, message: "Cette fonction accepte uniquement POST." },
      405,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse(
      { success: false, message: "Configuration Supabase incomplète." },
      500,
    );
  }

  if (!authorization) {
    return jsonResponse(
      { success: false, message: "Authentification requise." },
      401,
    );
  }

  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return jsonResponse(
      { success: false, message: "Jeton d'authentification absent." },
      401,
    );
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authData, error: authError } = await authClient.auth.getUser(
    token,
  );
  if (authError || !authData.user) {
    return jsonResponse(
      { success: false, message: "Session invalide ou expirée." },
      401,
    );
  }

  try {
    const body = await request.json() as SearchRequest;
    const latitude = requiredNumber(body.latitude, "latitude", -90, 90);
    const longitude = requiredNumber(body.longitude, "longitude", -180, 180);
    const radiusKm = requiredNumber(body.radius_km ?? 20, "radius_km", 1, 50);
    const fuelType = requiredFuelType(body.fuel_type);
    const sortBy = requiredSort(body.sort_by);
    const resultLimit = requiredInteger(
      body.result_limit,
      "result_limit",
      1,
      100,
      50,
    );
    const fieldPrefix = FUEL_FIELDS[fuelType];
    const key = cacheKey(latitude, longitude, radiusKm, fuelType);
    const now = new Date();

    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let stations: NormalizedStation[] | null = null;
    let sourceFetchedAt: string | null = null;
    let cacheHit = false;
    let truncated = false;

    try {
      const { data: cached } = await serviceClient
        .from("fuel_search_cache")
        .select("payload,source_fetched_at,expires_at")
        .eq("cache_key", key)
        .gt("expires_at", now.toISOString())
        .maybeSingle();

      if (cached && Array.isArray(cached.payload)) {
        stations = (cached.payload as NormalizedStation[])
          .map((station) => ({
            ...station,
            distance_km: Math.round(
              distanceKm(
                  latitude,
                  longitude,
                  station.latitude,
                  station.longitude,
                ) * 100,
            ) / 100,
          }))
          .filter((station) => station.distance_km <= radiusKm + 0.2);
        sourceFetchedAt = String(cached.source_fetched_at);
        cacheHit = true;
      }
    } catch (cacheError) {
      console.warn("Fuel cache read unavailable", cacheError);
    }

    if (stations === null) {
      sourceFetchedAt = now.toISOString();
      stations = [];
      let offset = 0;
      let totalCount = 0;

      while (offset < MAX_RECORDS) {
        const parameters = new URLSearchParams();
        parameters.set("limit", String(PAGE_SIZE));
        parameters.set("offset", String(offset));
        parameters.set(
          "where",
          `within_distance(geom, geom'POINT(${longitude} ${latitude})', ${radiusKm} km)`,
        );
        parameters.set(
          "select",
          [
            "id",
            "latitude",
            "longitude",
            "cp",
            "adresse",
            "ville",
            "geom",
            `${fieldPrefix}_prix`,
            `${fieldPrefix}_maj`,
            `${fieldPrefix}_rupture_debut`,
            `${fieldPrefix}_rupture_type`,
            "horaires_automate_24_24",
            "services_service",
          ].join(","),
        );

        const response = await fetch(`${OFFICIAL_API_URL}?${parameters}`, {
          method: "GET",
          headers: {
            Accept: "application/json",
            "User-Agent": "AutoClair-Fuel-Comparator/1.0",
          },
          signal: AbortSignal.timeout(20000),
        });

        if (!response.ok) {
          const responseText = await response.text();
          throw new Error(
            `La source officielle a répondu HTTP ${response.status}: ${responseText.substring(0, 300)}`,
          );
        }

        const officialData = await response.json() as OfficialResponse;
        const records = Array.isArray(officialData.results)
          ? officialData.results
          : [];
        totalCount = Number(officialData.total_count ?? 0);

        for (const record of records) {
          const station = normalizeStation(
            record,
            latitude,
            longitude,
            radiusKm,
            fuelType,
            fieldPrefix,
            sourceFetchedAt,
          );
          if (station && station.station_id.length > 0) stations.push(station);
        }

        offset += records.length;
        if (records.length < PAGE_SIZE || offset >= totalCount) break;
      }

      truncated = totalCount > MAX_RECORDS;

      const uniqueStations = new Map<string, NormalizedStation>();
      for (const station of stations) {
        uniqueStations.set(station.station_id, station);
      }
      stations = Array.from(uniqueStations.values());

      try {
        const expiresAt = new Date(
          now.getTime() + CACHE_DURATION_MINUTES * 60 * 1000,
        ).toISOString();

        await serviceClient.from("fuel_search_cache").upsert({
          cache_key: key,
          payload: stations,
          source_fetched_at: sourceFetchedAt,
          expires_at: expiresAt,
          updated_at: now.toISOString(),
        }, { onConflict: "cache_key" });

        await serviceClient
          .from("fuel_search_cache")
          .delete()
          .lt("expires_at", new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString());
      } catch (cacheError) {
        console.warn("Fuel cache write unavailable", cacheError);
      }
    }

    const results = sortStations(stations, sortBy).slice(0, resultLimit);

    return jsonResponse({
      success: true,
      fuel_type: fuelType,
      radius_km: radiusKm,
      sort_by: sortBy,
      cache_hit: cacheHit,
      source_fetched_at: sourceFetchedAt,
      result_count: results.length,
      matched_station_count: stations.length,
      truncated,
      results,
    });
  } catch (error) {
    console.error("Fuel station search failed", error);
    const message = error instanceof Error
      ? error.message
      : "La recherche des stations a échoué.";

    return jsonResponse({ success: false, message }, 500);
  }
});