import { createClient } from "npm:@supabase/supabase-js@2";

const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type RequestBody = {
  document_id?: string;
  vehicle_id?: string;
  refresh?: boolean;
};

type Suggestion = {
  user_id: string;
  vehicle_id: string | null;
  document_id: string;
  analysis_id: string | null;
  suggestion_type:
    | "EVENT"
    | "ODOMETER"
    | "EXPENSE"
    | "MAINTENANCE"
    | "WARRANTY"
    | "ADVICE";
  dedupe_key: string;
  title: string;
  payload: Record<string, unknown>;
  confidence: number | null;
  status: "PENDING";
};

function response(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload, null, 2), { status, headers });
}

function text(value: unknown): string | null {
  const normalized = value?.toString().trim();
  return normalized ? normalized : null;
}

function numberValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const parsed = Number(String(value ?? "").replace(/\s/g, "").replace(",", "."));
  return Number.isFinite(parsed) ? parsed : null;
}

function objectValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function objectList(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.filter(
      (item): item is Record<string, unknown> =>
        !!item && typeof item === "object" && !Array.isArray(item),
    )
    : [];
}

function normalize(value: unknown): string {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function maintenanceCode(description: string): {
  code: string;
  label: string;
  category: string;
} {
  const value = normalize(description);

  if (/filtre.*huile|huile.*filtre/.test(value)) {
    return { code: "OIL_FILTER", label: "Filtre à huile", category: "FILTERS" };
  }
  if (/vidange|huile moteur/.test(value)) {
    return { code: "ENGINE_OIL", label: "Vidange moteur", category: "ENGINE" };
  }
  if (/filtre.*air/.test(value)) {
    return { code: "AIR_FILTER", label: "Filtre à air moteur", category: "FILTERS" };
  }
  if (/filtre.*habitacle|filtre.*pollen/.test(value)) {
    return { code: "CABIN_FILTER", label: "Filtre d’habitacle", category: "FILTERS" };
  }
  if (/plaquette|disque|frein/.test(value)) {
    return { code: "BRAKE_SYSTEM_CHECK", label: "Freinage", category: "BRAKES" };
  }
  if (/pneu|roue/.test(value)) {
    return { code: "TYRE_CHECK", label: "Pneus", category: "TYRES" };
  }
  if (/distribution|courroie|chaine/.test(value)) {
    return { code: "TIMING_SYSTEM_CHECK", label: "Distribution", category: "ENGINE" };
  }
  if (/adblue/.test(value)) {
    return { code: "ADBLUE_SYSTEM_CHECK", label: "Système AdBlue", category: "EMISSIONS" };
  }
  if (/fap|filtre a particules/.test(value)) {
    return { code: "DPF_USAGE_CHECK", label: "Filtre à particules", category: "EMISSIONS" };
  }
  if (/batterie/.test(value)) {
    return { code: "BATTERY_12V_CHECK", label: "Batterie 12 V", category: "ELECTRICAL" };
  }
  if (/clim|climatisation/.test(value)) {
    return { code: "AIR_CONDITIONING_CHECK", label: "Climatisation", category: "COMFORT" };
  }

  return { code: "OTHER", label: description, category: "OTHER" };
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { headers });
  if (request.method !== "POST") {
    return response({ success: false, error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !anonKey || !authorization) {
    return response(
      {
        success: false,
        error: "SERVER_CONFIGURATION_ERROR",
        message: "Configuration ou session Supabase absente.",
      },
      500,
    );
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const body = (await request.json()) as RequestBody;
    const documentId = text(body.document_id);
    if (!documentId) {
      return response(
        {
          success: false,
          error: "DOCUMENT_ID_REQUIRED",
          message: "document_id est obligatoire.",
        },
        400,
      );
    }

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return response(
        {
          success: false,
          error: "AUTH_REQUIRED",
          message: "Votre session a expiré.",
        },
        401,
      );
    }
    const userId = userData.user.id;

    const { data: document, error: documentError } = await supabase
      .from("documents")
      .select("id,document_type,status,created_at")
      .eq("id", documentId)
      .single();

    if (documentError || !document) {
      return response(
        {
          success: false,
          error: "DOCUMENT_NOT_FOUND",
          message: "Ce document n’existe pas ou ne vous appartient pas.",
        },
        404,
      );
    }

    const { data: analysis, error: analysisError } = await supabase
      .from("document_analyses")
      .select("id,document_id,overall_confidence,result_json")
      .eq("document_id", documentId)
      .single();

    if (analysisError || !analysis) {
      return response(
        {
          success: false,
          error: "ANALYSIS_NOT_FOUND",
          message: "L’analyse du document n’est pas disponible.",
        },
        404,
      );
    }

    const result = objectValue(analysis.result_json);
    const vehicleInfo = objectValue(result.vehicle);
    const dates = objectValue(result.dates);
    const amounts = objectValue(result.amounts);
    const lineItems = objectList(result.line_items);
    const observations = objectList(result.observations);
    const confidence = numberValue(analysis.overall_confidence);

    let vehicleId = text(body.vehicle_id);
    const vin = normalize(vehicleInfo.vin);
    const registration = normalize(vehicleInfo.registration_number);

    const { data: vehicles, error: vehiclesError } = await supabase
      .from("vehicles")
      .select("id,vin,registration_number,make,model")
      .order("is_primary", { ascending: false });

    if (vehiclesError) {
      throw new Error(`Lecture des véhicules : ${vehiclesError.message}`);
    }

    if (vehicleId && !(vehicles ?? []).some((item: Record<string, unknown>) => item.id === vehicleId)) {
      return response(
        {
          success: false,
          error: "VEHICLE_NOT_FOUND",
          message: "Ce véhicule n’existe pas ou ne vous appartient pas.",
        },
        404,
      );
    }

    if (!vehicleId) {
      const exact = (vehicles ?? []).find((item: Record<string, unknown>) =>
        (vin && normalize(item.vin) === vin) ||
        (registration && normalize(item.registration_number) === registration)
      );
      vehicleId = exact?.id ?? ((vehicles ?? []).length === 1 ? vehicles?.[0]?.id : null);
    }

    if (body.refresh === true) {
      await supabase
        .from("vehicle_document_suggestions")
        .delete()
        .eq("document_id", documentId)
        .eq("status", "PENDING");
    }

    const suggestions: Suggestion[] = [];
    const documentDate = text(dates.document_date) ?? document.created_at;
    const mileage = numberValue(vehicleInfo.mileage);
    const totalAmount = numberValue(amounts.total_including_tax);
    const currency = text(amounts.currency) ?? "EUR";
    const documentType = text(result.document_type_detected) ?? document.document_type;

    if (mileage !== null && mileage >= 0) {
      suggestions.push({
        user_id: userId,
        vehicle_id: vehicleId,
        document_id: documentId,
        analysis_id: analysis.id,
        suggestion_type: "ODOMETER",
        dedupe_key: `ODOMETER:${Math.round(mileage)}`,
        title: `Kilométrage relevé : ${Math.round(mileage)} km`,
        payload: {
          mileage: Math.round(mileage),
          occurred_at: documentDate,
        },
        confidence,
        status: "PENDING",
      });
    }

    const eventType = documentType === "invoice"
      ? "MAINTENANCE"
      : documentType === "estimate"
      ? "REPAIR"
      : "REPAIR";
    const eventStatus = documentType === "invoice" ? "COMPLETED" : "RECOMMENDED";

    suggestions.push({
      user_id: userId,
      vehicle_id: vehicleId,
      document_id: documentId,
      analysis_id: analysis.id,
      suggestion_type: "EVENT",
      dedupe_key: "DOCUMENT_EVENT",
      title: documentType === "invoice"
        ? "Intervention détectée dans la facture"
        : "Intervention proposée dans le document",
      payload: {
        event_type: eventType,
        status: eventStatus,
        title: documentType === "invoice"
          ? "Entretien ou réparation"
          : "Devis ou intervention recommandée",
        occurred_at: documentDate,
        mileage,
        amount: totalAmount,
        currency,
        provider_name: text(objectValue(result.parties).garage_name),
        description: text(result.summary),
        line_items: lineItems,
      },
      confidence,
      status: "PENDING",
    });

    lineItems.forEach((item, index) => {
      const description = text(item.description);
      if (!description) return;
      const catalog = maintenanceCode(description);
      const assessment = text(item.necessity_assessment);
      const status = documentType === "invoice" ? "COMPLETED" : "RECOMMENDED";

      suggestions.push({
        user_id: userId,
        vehicle_id: vehicleId,
        document_id: documentId,
        analysis_id: analysis.id,
        suggestion_type: "MAINTENANCE",
        dedupe_key: `LINE:${index}:${normalize(description).slice(0, 60)}`,
        title: description,
        payload: {
          event_type: "MAINTENANCE",
          status,
          title: description,
          occurred_at: documentDate,
          mileage,
          amount: numberValue(item.total_excluding_tax),
          currency,
          description: text(item.explanation),
          item_code: catalog.code,
          item_label: catalog.label,
          category: catalog.category,
          necessity_assessment: assessment,
        },
        confidence,
        status: "PENDING",
      });
    });

    observations.forEach((item, index) => {
      const title = text(item.title) ?? "Point à vérifier";
      const message = text(item.explanation) ?? title;
      const level = text(item.level);
      suggestions.push({
        user_id: userId,
        vehicle_id: vehicleId,
        document_id: documentId,
        analysis_id: analysis.id,
        suggestion_type: "ADVICE",
        dedupe_key: `OBSERVATION:${index}:${normalize(title).slice(0, 60)}`,
        title,
        payload: {
          advice_type: "DOCUMENT",
          title,
          message,
          priority: level === "important"
            ? "HIGH"
            : level === "attention"
            ? "MEDIUM"
            : "LOW",
          rationale: "Conseil créé à partir d’une observation du document analysé.",
        },
        confidence,
        status: "PENDING",
      });
    });

    const { data: saved, error: saveError } = await supabase
      .from("vehicle_document_suggestions")
      .upsert(suggestions, {
        onConflict: "document_id,dedupe_key",
        ignoreDuplicates: false,
      })
      .select();

    if (saveError) {
      throw new Error(`Enregistrement des suggestions : ${saveError.message}`);
    }

    return response({
      success: true,
      status: "SUGGESTIONS_READY",
      document_id: documentId,
      vehicle_id: vehicleId,
      vehicle_match_status: vehicleId ? "MATCHED" : "SELECTION_REQUIRED",
      suggestion_count: saved?.length ?? 0,
      suggestions: saved ?? [],
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Vehicle timeline suggestion extraction failed", { message });
    return response(
      {
        success: false,
        error: "SUGGESTION_EXTRACTION_FAILED",
        message,
      },
      500,
    );
  }
});