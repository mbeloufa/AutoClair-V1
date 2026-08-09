import { authenticate } from "../_shared/auth.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  buildAiInput,
  buildMarketAndSaleAnalysis,
  calculateDataQuality,
  collectUsedSourceIds,
  filterInvalidSourceIds,
  type SaleScenario,
  type SourceRecord,
} from "../_shared/vehicle_analysis.ts";
import {
  asBoolean,
  asString,
  isRecord,
  readJsonBody,
  safeError,
  sha256Hex,
  type JsonMap,
} from "../_shared/utils.ts";
import { REPORT_SCHEMA } from "./report_schema.ts";
import {
  PROMPT_VERSION,
  RULES_VERSION,
  SYSTEM_PROMPT,
} from "./prompt.ts";

type ReportRow = JsonMap & {
  id?: unknown;
  status?: unknown;
  result_json?: unknown;
};

function statusForError(message: string): number {
  if (
    message === "AUTHENTICATION_REQUIRED" ||
    message === "INVALID_OR_EXPIRED_TOKEN"
  ) return 401;
  if (
    message === "VEHICLE_NOT_FOUND_OR_FORBIDDEN" ||
    message === "REPORT_NOT_FOUND"
  ) return 404;
  if (
    message === "INVALID_JSON_BODY" ||
    message === "VEHICLE_ID_REQUIRED" ||
    message === "INVALID_ACTION"
  ) return 400;
  if (message === "INSUFFICIENT_VEHICLE_DATA") return 422;
  if (
    message === "PAYWALL_REQUIRED" ||
    message === "NO_REPORT_CREDIT"
  ) return 402;
  return 500;
}

function extractOpenAiText(payload: JsonMap): string {
  const direct = asString(payload.output_text);
  if (direct) return direct;

  const output = Array.isArray(payload.output) ? payload.output : [];
  for (const item of output) {
    if (!isRecord(item) || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (!isRecord(content)) continue;
      if (content.type === "refusal") {
        const refusal = asString(content.refusal) ?? "OPENAI_REFUSAL";
        throw new Error(`OPENAI_REFUSAL:${refusal}`);
      }
      const text = asString(content.text);
      if (text) return text;
    }
  }

  throw new Error("OPENAI_EMPTY_STRUCTURED_OUTPUT");
}

async function callOpenAi(input: JsonMap): Promise<{
  model: string;
  report: JsonMap;
}> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  const model = Deno.env.get("AUTOCLAIR_REPORT_MODEL") ??
    Deno.env.get("OPENAI_MODEL");

  if (!apiKey) throw new Error("OPENAI_API_KEY_MISSING");
  if (!model) throw new Error("OPENAI_MODEL_MISSING");

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      store: false,
      instructions: SYSTEM_PROMPT,
      input: JSON.stringify(input),
      max_output_tokens: 7000,
      text: {
        format: {
          type: "json_schema",
          name: "autoclair_vehicle_360_report",
          strict: true,
          schema: REPORT_SCHEMA,
        },
      },
    }),
  });

  const payload = await response.json().catch(() => ({})) as JsonMap;
  if (!response.ok) {
    const error = isRecord(payload.error)
      ? asString(payload.error.message)
      : null;
    throw new Error(
      `OPENAI_HTTP_${response.status}:${error ?? "UNKNOWN_OPENAI_ERROR"}`,
    );
  }

  const text = extractOpenAiText(payload);
  let report: unknown;

  try {
    report = JSON.parse(text);
  } catch {
    throw new Error("OPENAI_INVALID_JSON");
  }

  if (!isRecord(report)) throw new Error("OPENAI_INVALID_REPORT_OBJECT");
  return { model, report };
}

async function loadReport(
  adminClient: ReturnType<typeof import("npm:@supabase/supabase-js@2")["createClient"]>,
  reportId: string,
  userId: string,
): Promise<JsonMap | null> {
  const { data: report, error: reportError } = await adminClient
    .from("vehicle_analysis_reports")
    .select("*")
    .eq("id", reportId)
    .eq("user_id", userId)
    .maybeSingle();

  if (reportError) throw new Error(`REPORT_READ_FAILED:${reportError.message}`);
  if (!report) return null;

  const [{ data: scenarios, error: scenarioError }, {
    data: sources,
    error: sourceError,
  }] = await Promise.all([
    adminClient
      .from("vehicle_sale_scenarios")
      .select("*")
      .eq("report_id", reportId)
      .eq("user_id", userId)
      .order("scenario_code"),
    adminClient
      .from("vehicle_report_sources")
      .select("*")
      .eq("report_id", reportId)
      .eq("user_id", userId)
      .order("source_type")
      .order("source_label"),
  ]);

  if (scenarioError) {
    throw new Error(`SCENARIO_READ_FAILED:${scenarioError.message}`);
  }
  if (sourceError) {
    throw new Error(`SOURCE_READ_FAILED:${sourceError.message}`);
  }

  const sanitizedReport = { ...report } as JsonMap;
  delete sanitizedReport.user_id;
  delete sanitizedReport.input_snapshot;
  delete sanitizedReport.payment_reference;

  return {
    report: sanitizedReport,
    scenarios: scenarios ?? [],
    sources: sources ?? [],
  };
}

function scenarioRows(
  reportId: string,
  userId: string,
  scenarios: SaleScenario[],
): JsonMap[] {
  return scenarios.map((scenario) => ({
    user_id: userId,
    report_id: reportId,
    scenario_code: scenario.scenario_code,
    expected_sale_value_eur: scenario.expected_sale_value_eur,
    required_costs_eur: scenario.required_costs_eur,
    holding_costs_eur: scenario.holding_costs_eur,
    expected_net_value_eur: scenario.expected_net_value_eur,
    estimated_delay_days: scenario.estimated_delay_days,
    confidence_score: scenario.confidence_score,
    explanation: scenario.explanation,
    details: scenario.details,
  }));
}

function sourceRows(
  reportId: string,
  userId: string,
  sources: SourceRecord[],
  usedIds: Set<string>,
): JsonMap[] {
  return sources
    .filter((source) => usedIds.has(source.source_id))
    .slice(0, 100)
    .map((source) => ({
      user_id: userId,
      report_id: reportId,
      source_type: source.source_type,
      source_id: source.source_id,
      source_label: source.source_label,
      source_date: source.source_date,
      confidence_level: source.confidence,
      metadata: {
        generated_from_snapshot: true,
      },
    }));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  let reportId: string | null = null;
  let userId: string | null = null;
  let creditWasReserved = false;
  let adminClient:
    | ReturnType<typeof import("npm:@supabase/supabase-js@2")["createClient"]>
    | null = null;

  try {
    const auth = await authenticate(req);
    adminClient = auth.adminClient;
    userId = auth.user.id;

    const body = await readJsonBody(req);
    const action = (asString(body.action) ?? "generate").toLowerCase();
    const vehicleId = asString(body.vehicle_id);
    const forceRefresh = asBoolean(body.force_refresh);
    const requestKey = asString(body.request_key) ?? crypto.randomUUID();

    if (!vehicleId) throw new Error("VEHICLE_ID_REQUIRED");
    if (!["precheck", "latest", "generate"].includes(action)) {
      throw new Error("INVALID_ACTION");
    }

    const { data: vehicle, error: vehicleError } = await auth.userClient
      .from("vehicles")
      .select("id")
      .eq("id", vehicleId)
      .maybeSingle();

    if (vehicleError) {
      throw new Error(`VEHICLE_CHECK_FAILED:${vehicleError.message}`);
    }
    if (!vehicle) throw new Error("VEHICLE_NOT_FOUND_OR_FORBIDDEN");

    if (action === "latest") {
      const { data, error } = await auth.userClient.rpc(
        "get_latest_vehicle_analysis_report",
        { p_vehicle_id: vehicleId },
      );
      if (error) throw new Error(`LATEST_REPORT_FAILED:${error.message}`);
      return jsonResponse({ success: true, data });
    }

    const { data: snapshotData, error: snapshotError } =
      await auth.userClient.rpc(
        "build_vehicle_analysis_snapshot",
        { p_vehicle_id: vehicleId },
      );

    if (snapshotError) {
      throw new Error(`SNAPSHOT_FAILED:${snapshotError.message}`);
    }
    if (!isRecord(snapshotData)) throw new Error("SNAPSHOT_INVALID");

    const quality = calculateDataQuality(snapshotData);
    const { compactSnapshot, sources } = buildAiInput(snapshotData, quality);
    const market = buildMarketAndSaleAnalysis(snapshotData, quality);

    if (action === "precheck") {
      const { data: latestReport, error: latestError } =
        await auth.userClient.rpc(
          "get_latest_vehicle_analysis_report",
          { p_vehicle_id: vehicleId },
        );
      if (latestError) {
        throw new Error(`LATEST_REPORT_FAILED:${latestError.message}`);
      }

      return jsonResponse({
        success: true,
        action: "precheck",
        vehicle_id: vehicleId,
        data_quality: quality,
        market_data: market.marketData,
        timing: market.timing,
        latest_report: latestReport,
      });
    }

    if (!quality.can_generate) throw new Error("INSUFFICIENT_VEHICLE_DATA");

    const snapshotForHash = {
      vehicle: snapshotData.vehicle,
      datasets: snapshotData.datasets,
      derived: snapshotData.derived,
    };
    const snapshotHash = await sha256Hex(snapshotForHash);

    const cacheDays = Number(
      Deno.env.get("AUTOCLAIR_REPORT_CACHE_DAYS") ?? "30",
    );
    const cutoff = new Date(
      Date.now() - Math.max(1, cacheDays) * 86_400_000,
    ).toISOString();

    if (!forceRefresh) {
      const { data: cached, error: cacheError } = await adminClient
        .from("vehicle_analysis_reports")
        .select("id")
        .eq("user_id", userId)
        .eq("vehicle_id", vehicleId)
        .eq("status", "completed")
        .eq("source_snapshot_hash", snapshotHash)
        .gte("completed_at", cutoff)
        .order("completed_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (cacheError) {
        throw new Error(`REPORT_CACHE_FAILED:${cacheError.message}`);
      }

      if (cached?.id) {
        const loaded = await loadReport(adminClient, cached.id, userId);
        return jsonResponse({
          success: true,
          cached: true,
          data: loaded,
        });
      }
    }

    const { data: idempotent, error: idempotentError } = await adminClient
      .from("vehicle_analysis_reports")
      .select("id,status")
      .eq("user_id", userId)
      .eq("request_key", requestKey)
      .maybeSingle();

    if (idempotentError) {
      throw new Error(`IDEMPOTENCY_CHECK_FAILED:${idempotentError.message}`);
    }

    if (idempotent?.id) {
      const loaded = await loadReport(adminClient, idempotent.id, userId);
      return jsonResponse({
        success: idempotent.status === "completed",
        idempotent: true,
        data: loaded,
      }, idempotent.status === "completed" ? 200 : 202);
    }

    if (!Deno.env.get("OPENAI_API_KEY")) {
      throw new Error("OPENAI_API_KEY_MISSING");
    }
    if (
      !Deno.env.get("AUTOCLAIR_REPORT_MODEL") &&
      !Deno.env.get("OPENAI_MODEL")
    ) {
      throw new Error("OPENAI_MODEL_MISSING");
    }

    const billingMode = "credits";

    const { data: report, error: reportError } = await adminClient
      .from("vehicle_analysis_reports")
      .insert({
        user_id: userId,
        vehicle_id: vehicleId,
        report_type: "vehicle_360",
        status: "processing",
        request_key: requestKey,
        access_mode: billingMode,
        source_snapshot_hash: snapshotHash,
        input_snapshot: {
          snapshot_version: snapshotData.snapshot_version,
          source_snapshot_hash: snapshotHash,
          data_quality: quality,
          market_available: market.marketData.available,
        },
        data_quality_score: quality.score,
        rules_version: RULES_VERSION,
        prompt_version: PROMPT_VERSION,
      })
      .select("*")
      .single();

    if (reportError || !report) {
      throw new Error(
        `REPORT_CREATE_FAILED:${reportError?.message ?? "UNKNOWN"}`,
      );
    }

    reportId = String(report.id);

    const { data: access, error: accessError } = await adminClient.rpc(
      "reserve_vehicle_report_access",
      {
        p_user_id: userId,
        p_report_id: reportId,
        p_billing_mode: billingMode,
      },
    );

    if (accessError) {
      throw new Error(`ACCESS_RESERVATION_FAILED:${accessError.message}`);
    }

    if (!isRecord(access) || access.granted !== true) {
      const reason = isRecord(access)
        ? asString(access.reason) ?? "PAYWALL_REQUIRED"
        : "PAYWALL_REQUIRED";

      await adminClient
        .from("vehicle_analysis_reports")
        .update({
          status: "failed",
          error_code: reason,
          error_message: "Acces premium requis.",
        })
        .eq("id", reportId);

      throw new Error(reason);
    }

    creditWasReserved = access.credit_consumed === true;

    const aiInput = {
      task: "Generer le bilan professionnel AutoClair 360.",
      deterministic_market_data: market.marketData,
      deterministic_sale_timing: market.timing,
      deterministic_sale_scenarios: market.scenarios,
      vehicle_snapshot: compactSnapshot,
    };

    const openAi = await callOpenAi(aiInput);
    const allowedSources = new Set(sources.map((source) => source.source_id));
    const filteredAi = filterInvalidSourceIds(
      openAi.report,
      allowedSources,
    ) as JsonMap;

    const finalResult: JsonMap = {
      ...filteredAi,
      data_quality: quality,
      market_data: market.marketData,
      sale_analysis: {
        ...(isRecord(filteredAi.sale_analysis)
          ? filteredAi.sale_analysis
          : {}),
        timing: market.timing,
        scenarios: market.scenarios,
      },
      generation: {
        prompt_version: PROMPT_VERSION,
        rules_version: RULES_VERSION,
        generated_at: new Date().toISOString(),
        ai_model: openAi.model,
      },
    };

    const usedSourceIds = collectUsedSourceIds(finalResult);
    const scenariosToInsert = scenarioRows(
      reportId,
      userId,
      market.scenarios,
    );
    const sourcesToInsert = sourceRows(
      reportId,
      userId,
      sources,
      usedSourceIds,
    );

    const { error: scenarioDeleteError } = await adminClient
      .from("vehicle_sale_scenarios")
      .delete()
      .eq("report_id", reportId);

    if (scenarioDeleteError) {
      throw new Error(
        `SCENARIO_CLEAR_FAILED:${scenarioDeleteError.message}`,
      );
    }

    if (scenariosToInsert.length) {
      const { error } = await adminClient
        .from("vehicle_sale_scenarios")
        .insert(scenariosToInsert);
      if (error) throw new Error(`SCENARIO_SAVE_FAILED:${error.message}`);
    }

    const { error: sourceDeleteError } = await adminClient
      .from("vehicle_report_sources")
      .delete()
      .eq("report_id", reportId);

    if (sourceDeleteError) {
      throw new Error(`SOURCE_CLEAR_FAILED:${sourceDeleteError.message}`);
    }

    if (sourcesToInsert.length) {
      const { error } = await adminClient
        .from("vehicle_report_sources")
        .insert(sourcesToInsert);
      if (error) throw new Error(`SOURCE_SAVE_FAILED:${error.message}`);
    }

    const valuationProvider = isRecord(market.marketData.private_sale)
      ? asString(market.marketData.private_sale.provider)
      : null;

    const { error: completeError } = await adminClient
      .from("vehicle_analysis_reports")
      .update({
        status: "completed",
        result_json: finalResult,
        overall_confidence_score: quality.score,
        ai_provider: "openai",
        ai_model: openAi.model,
        valuation_provider: valuationProvider,
        credit_consumed: creditWasReserved,
        completed_at: new Date().toISOString(),
        error_code: null,
        error_message: null,
      })
      .eq("id", reportId)
      .eq("user_id", userId);

    if (completeError) {
      throw new Error(`REPORT_COMPLETE_FAILED:${completeError.message}`);
    }

    const loaded = await loadReport(adminClient, reportId, userId);
    return jsonResponse({
      success: true,
      cached: false,
      data: loaded,
    });
  } catch (error) {
    const message = safeError(error);

    if (adminClient && reportId && userId) {
      await adminClient
        .from("vehicle_analysis_reports")
        .update({
          status: "failed",
          error_code: message.split(":")[0].slice(0, 120),
          error_message: message.slice(0, 1000),
        })
        .eq("id", reportId)
        .eq("user_id", userId);

      if (creditWasReserved) {
        await adminClient.rpc("release_vehicle_report_access", {
          p_user_id: userId,
          p_report_id: reportId,
          p_reason: message.slice(0, 300),
        });
      }
    }

    return jsonResponse({
      success: false,
      error: message.split(":")[0],
      message,
    }, statusForError(message.split(":")[0]));
  }
});
