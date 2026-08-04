import { authenticate } from "../_shared/auth.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  asArray,
  asInteger,
  asNumber,
  asString,
  daysBetween,
  isRecord,
  isoDate,
  readJsonBody,
  safeError,
  type JsonMap,
} from "../_shared/utils.ts";

type NormalizedValuation = {
  valuation_type:
    | "private_sale"
    | "professional_retail"
    | "trade_in"
    | "b2b"
    | "market";
  value_low_eur: number | null;
  value_mid_eur: number;
  value_high_eur: number | null;
  estimated_days_to_sell: number | null;
  liquidity_score: number | null;
  sample_size: number | null;
  confidence_score: number | null;
};

type NormalizedForecast = {
  forecast_date: string;
  horizon_months: number;
  scenario: "low" | "central" | "high";
  predicted_mileage: number | null;
  value_eur: number;
  confidence_score: number | null;
  method: string;
  model_version: string | null;
  assumptions: JsonMap;
};

function statusForError(message: string): number {
  if (
    message === "AUTHENTICATION_REQUIRED" ||
    message === "INVALID_OR_EXPIRED_TOKEN"
  ) return 401;
  if (message === "VEHICLE_NOT_FOUND_OR_FORBIDDEN") return 404;
  if (
    message === "INVALID_JSON_BODY" ||
    message === "VEHICLE_ID_REQUIRED"
  ) return 400;
  if (
    message === "VALUATION_PROVIDER_NOT_CONFIGURED" ||
    message === "VALUATION_NOT_AVAILABLE"
  ) return 409;
  return 500;
}

function normalizeValuation(value: unknown): NormalizedValuation {
  if (!isRecord(value)) throw new Error("INVALID_PROVIDER_VALUATION");

  const type = asString(value.valuation_type);
  const allowed = [
    "private_sale",
    "professional_retail",
    "trade_in",
    "b2b",
    "market",
  ];

  if (!type || !allowed.includes(type)) {
    throw new Error("INVALID_PROVIDER_VALUATION_TYPE");
  }

  const mid = asNumber(value.value_mid_eur);
  if (mid === null || mid <= 0) {
    throw new Error("INVALID_PROVIDER_MID_VALUE");
  }

  const low = asNumber(value.value_low_eur);
  const high = asNumber(value.value_high_eur);

  if (low !== null && low > mid) {
    throw new Error("INVALID_PROVIDER_VALUE_RANGE");
  }
  if (high !== null && high < mid) {
    throw new Error("INVALID_PROVIDER_VALUE_RANGE");
  }

  return {
    valuation_type: type as NormalizedValuation["valuation_type"],
    value_low_eur: low,
    value_mid_eur: mid,
    value_high_eur: high,
    estimated_days_to_sell: asInteger(value.estimated_days_to_sell),
    liquidity_score: asNumber(value.liquidity_score),
    sample_size: asInteger(value.sample_size),
    confidence_score: asNumber(value.confidence_score),
  };
}

function normalizeForecast(value: unknown): NormalizedForecast {
  if (!isRecord(value)) throw new Error("INVALID_PROVIDER_FORECAST");

  const date = isoDate(value.forecast_date);
  const horizon = asInteger(value.horizon_months);
  const scenario = asString(value.scenario);
  const amount = asNumber(value.value_eur);
  const method = asString(value.method);

  if (!date || horizon === null || horizon < 0) {
    throw new Error("INVALID_PROVIDER_FORECAST_DATE");
  }
  if (!scenario || !["low", "central", "high"].includes(scenario)) {
    throw new Error("INVALID_PROVIDER_FORECAST_SCENARIO");
  }
  if (amount === null || amount <= 0) {
    throw new Error("INVALID_PROVIDER_FORECAST_VALUE");
  }
  if (!method) throw new Error("INVALID_PROVIDER_FORECAST_METHOD");

  return {
    forecast_date: date,
    horizon_months: horizon,
    scenario: scenario as NormalizedForecast["scenario"],
    predicted_mileage: asInteger(value.predicted_mileage),
    value_eur: amount,
    confidence_score: asNumber(value.confidence_score),
    method,
    model_version: asString(value.model_version),
    assumptions: isRecord(value.assumptions) ? value.assumptions : {},
  };
}

async function loadCached(
  adminClient: ReturnType<typeof import("npm:@supabase/supabase-js@2")["createClient"]>,
  userId: string,
  vehicleId: string,
): Promise<JsonMap> {
  const [{ data: valuations, error: valuationError }, {
    data: forecasts,
    error: forecastError,
  }] = await Promise.all([
    adminClient
      .from("vehicle_market_valuations")
      .select(
        "id,provider,provider_reference,valuation_date,valuation_type,value_low_eur,value_mid_eur,value_high_eur,estimated_days_to_sell,liquidity_score,sample_size,confidence_score,mileage,vehicle_variant_reference,created_at",
      )
      .eq("user_id", userId)
      .eq("vehicle_id", vehicleId)
      .order("valuation_date", { ascending: false }),
    adminClient
      .from("vehicle_value_forecasts")
      .select(
        "id,source_valuation_id,forecast_date,horizon_months,scenario,predicted_mileage,value_eur,confidence_score,method,model_version,assumptions,created_at",
      )
      .eq("user_id", userId)
      .eq("vehicle_id", vehicleId)
      .order("forecast_date", { ascending: true }),
  ]);

  if (valuationError) {
    throw new Error(`VALUATION_CACHE_READ_FAILED:${valuationError.message}`);
  }
  if (forecastError) {
    throw new Error(`FORECAST_CACHE_READ_FAILED:${forecastError.message}`);
  }

  return {
    valuations: valuations ?? [],
    forecasts: forecasts ?? [],
  };
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
    const vehicleId = asString(body.vehicle_id);
    const forceRefresh = body.force_refresh === true;

    if (!vehicleId) throw new Error("VEHICLE_ID_REQUIRED");

    const { data: vehicle, error: vehicleError } = await auth.userClient
      .from("vehicles")
      .select("*")
      .eq("id", vehicleId)
      .maybeSingle();

    if (vehicleError) {
      throw new Error(`VEHICLE_CHECK_FAILED:${vehicleError.message}`);
    }
    if (!vehicle) throw new Error("VEHICLE_NOT_FOUND_OR_FORBIDDEN");

    const cached = await loadCached(
      auth.adminClient,
      auth.user.id,
      vehicleId,
    );

    const firstCached = asArray(cached.valuations)[0];
    const firstDate = isRecord(firstCached)
      ? isoDate(firstCached.valuation_date)
      : null;
    const cacheDays = Number(
      Deno.env.get("AUTOCLAIR_VALUATION_CACHE_DAYS") ?? "30",
    );

    if (
      !forceRefresh &&
      firstDate &&
      daysBetween(firstDate) <= Math.max(1, cacheDays)
    ) {
      return jsonResponse({
        success: true,
        cached: true,
        data: cached,
      });
    }

    const mode = (
      Deno.env.get("AUTOCLAIR_VALUATION_MODE") ?? "cache_only"
    ).toLowerCase();

    if (mode === "cache_only") {
      if (asArray(cached.valuations).length) {
        return jsonResponse({
          success: true,
          cached: true,
          stale: true,
          data: cached,
        });
      }
      throw new Error("VALUATION_PROVIDER_NOT_CONFIGURED");
    }

    if (mode !== "normalized_http") {
      throw new Error("INVALID_VALUATION_MODE");
    }

    const providerUrl = Deno.env.get("AUTOCLAIR_VALUATION_API_URL");
    if (!providerUrl) throw new Error("VALUATION_PROVIDER_NOT_CONFIGURED");

    const providerToken = Deno.env.get("AUTOCLAIR_VALUATION_API_TOKEN");
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (providerToken) {
      headers.Authorization = `Bearer ${providerToken}`;
    }

    const safeVehicle = { ...vehicle } as JsonMap;
    for (const key of [
      "user_id",
      "created_by",
      "storage_path",
      "photo_url",
    ]) {
      delete safeVehicle[key];
    }

    const response = await fetch(providerUrl, {
      method: "POST",
      headers,
      body: JSON.stringify({
        contract_version: "autoclair-valuation-1.0",
        vehicle: safeVehicle,
        requested_outputs: [
          "current_valuations",
          "historical_valuations",
          "forecasts",
        ],
      }),
    });

    const payload = await response.json().catch(() => ({})) as JsonMap;
    if (!response.ok) {
      const providerMessage = isRecord(payload.error)
        ? asString(payload.error.message)
        : null;
      throw new Error(
        `VALUATION_PROVIDER_HTTP_${response.status}:${
          providerMessage ?? "UNKNOWN_PROVIDER_ERROR"
        }`,
      );
    }

    const provider = asString(payload.provider);
    const valuationDate = isoDate(payload.valuation_date);
    if (!provider || !valuationDate) {
      throw new Error("INVALID_PROVIDER_RESPONSE_HEADER");
    }

    const providerReference = asString(payload.provider_reference);
    const vehicleVariantReference = asString(
      payload.vehicle_variant_reference,
    );
    const mileage = asInteger(payload.mileage);

    const current = asArray(payload.valuations).map(normalizeValuation);
    const history = asArray(payload.history).filter(isRecord);
    const forecasts = asArray(payload.forecasts).map(normalizeForecast);

    if (!current.length && !history.length) {
      throw new Error("VALUATION_NOT_AVAILABLE");
    }

    const valuationRows: JsonMap[] = [];

    for (const item of current) {
      valuationRows.push({
        user_id: auth.user.id,
        vehicle_id: vehicleId,
        provider,
        provider_reference: providerReference,
        valuation_date: valuationDate,
        valuation_type: item.valuation_type,
        value_low_eur: item.value_low_eur,
        value_mid_eur: item.value_mid_eur,
        value_high_eur: item.value_high_eur,
        estimated_days_to_sell: item.estimated_days_to_sell,
        liquidity_score: item.liquidity_score,
        sample_size: item.sample_size,
        confidence_score: item.confidence_score,
        mileage,
        vehicle_variant_reference: vehicleVariantReference,
        raw_payload: {
          contract_version: "autoclair-valuation-1.0",
          provider_model_version: asString(payload.model_version),
        },
      });
    }

    for (const raw of history) {
      const item = normalizeValuation(raw);
      const date = isoDate(raw.valuation_date);
      if (!date) throw new Error("INVALID_PROVIDER_HISTORY_DATE");

      valuationRows.push({
        user_id: auth.user.id,
        vehicle_id: vehicleId,
        provider,
        provider_reference: providerReference,
        valuation_date: date,
        valuation_type: item.valuation_type,
        value_low_eur: item.value_low_eur,
        value_mid_eur: item.value_mid_eur,
        value_high_eur: item.value_high_eur,
        estimated_days_to_sell: item.estimated_days_to_sell,
        liquidity_score: item.liquidity_score,
        sample_size: item.sample_size,
        confidence_score: item.confidence_score,
        mileage: asInteger(raw.mileage) ?? mileage,
        vehicle_variant_reference: vehicleVariantReference,
        raw_payload: {
          contract_version: "autoclair-valuation-1.0",
          historical: true,
          provider_model_version: asString(payload.model_version),
        },
      });
    }

    const { data: savedValuations, error: valuationSaveError } =
      await auth.adminClient
        .from("vehicle_market_valuations")
        .upsert(valuationRows, {
          onConflict:
            "vehicle_id,provider,valuation_date,valuation_type",
        })
        .select("id,valuation_date,valuation_type");

    if (valuationSaveError) {
      throw new Error(
        `VALUATION_SAVE_FAILED:${valuationSaveError.message}`,
      );
    }

    const sourceValuationId = Array.isArray(savedValuations)
      ? savedValuations.find((row) =>
        row.valuation_date === valuationDate
      )?.id ?? null
      : null;

    if (forecasts.length) {
      const forecastRows = forecasts.map((forecast) => ({
        user_id: auth.user.id,
        vehicle_id: vehicleId,
        source_valuation_id: sourceValuationId,
        forecast_date: forecast.forecast_date,
        horizon_months: forecast.horizon_months,
        scenario: forecast.scenario,
        predicted_mileage: forecast.predicted_mileage,
        value_eur: forecast.value_eur,
        confidence_score: forecast.confidence_score,
        method: forecast.method,
        model_version: forecast.model_version,
        assumptions: forecast.assumptions,
      }));

      const { error: forecastSaveError } = await auth.adminClient
        .from("vehicle_value_forecasts")
        .upsert(forecastRows, {
          onConflict:
            "vehicle_id,forecast_date,horizon_months,scenario,method",
        });

      if (forecastSaveError) {
        throw new Error(
          `FORECAST_SAVE_FAILED:${forecastSaveError.message}`,
        );
      }
    }

    const refreshed = await loadCached(
      auth.adminClient,
      auth.user.id,
      vehicleId,
    );

    return jsonResponse({
      success: true,
      cached: false,
      data: refreshed,
    });
  } catch (error) {
    const message = safeError(error);
    const code = message.split(":")[0];

    return jsonResponse({
      success: false,
      error: code,
      message,
    }, statusForError(code));
  }
});
