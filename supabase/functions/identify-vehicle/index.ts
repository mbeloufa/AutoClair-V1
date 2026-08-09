const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonRecord = Record<string, unknown>;

function jsonResponse(
  status: number,
  body: JsonRecord,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function compactRegistration(value: string): string {
  return value
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .trim();
}

function formatRegistration(value: string): string {
  const compact = compactRegistration(value);

  const siv = compact.match(/^([A-HJ-NP-TV-Z]{2})(\d{3})([A-HJ-NP-TV-Z]{2})$/);
  if (siv) {
    return `${siv[1]}-${siv[2]}-${siv[3]}`;
  }

  const fni = compact.match(/^(\d{1,4})([A-HJ-NP-TV-Z]{1,3})(\d{2,3})$/);
  if (fni) {
    return `${fni[1]} ${fni[2]} ${fni[3]}`;
  }

  return "";
}

function nullableText(value: unknown): string | null {
  const text = typeof value === "string" ? value.trim() : "";
  return text.length > 0 ? text : null;
}

function parseYear(data: JsonRecord): number | null {
  for (const key of ["date1erCir_us", "date1erCir_fr"]) {
    const value = nullableText(data[key]);
    if (!value) continue;

    const match = value.match(/(19|20)\d{2}/);
    if (!match) continue;

    const year = Number.parseInt(match[0], 10);
    const maxYear = new Date().getUTCFullYear() + 1;
    if (year >= 1886 && year <= maxYear) return year;
  }

  return null;
}

function normalizeFuel(value: unknown): string | null {
  const raw = nullableText(value);
  if (!raw) return null;

  const normalized = raw
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");

  if (normalized.includes("diesel") || normalized.includes("gazole")) {
    return "Diesel";
  }
  if (normalized.includes("elect")) {
    return "Électrique";
  }
  if (normalized.includes("hybride rechargeable") ||
      normalized.includes("plug-in")) {
    return "Hybride rechargeable";
  }
  if (normalized.includes("hybride")) {
    return "Hybride";
  }
  if (normalized.includes("gpl")) {
    return "GPL";
  }
  if (normalized.includes("essence") ||
      normalized.includes("sans plomb") ||
      normalized.includes("gasoline")) {
    return "Essence";
  }

  return null;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse(405, {
      success: false,
      error_code: "METHOD_NOT_ALLOWED",
      message: "Méthode non autorisée.",
    });
  }

  let payload: JsonRecord;
  try {
    payload = await request.json() as JsonRecord;
  } catch {
    return jsonResponse(400, {
      success: false,
      error_code: "INVALID_JSON",
      message: "Requête invalide.",
    });
  }

  const registration = formatRegistration(
    typeof payload.registration === "string" ? payload.registration : "",
  );

  if (!registration) {
    return jsonResponse(400, {
      success: false,
      error_code: "VEHICLE_REGISTRATION_INVALID",
      message:
        "Format d’immatriculation français non reconnu. "
        + "Utilisez par exemple AB-123-CD.",
    });
  }

  const token = Deno.env.get("API_PLAQUE_IMMATRICULATION_TOKEN")?.trim();

  if (!token) {
    return jsonResponse(503, {
      success: false,
      error_code: "VEHICLE_LOOKUP_NOT_CONFIGURED",
      message:
        "L’identification automatique n’est pas encore activée. "
        + "Vous pouvez continuer manuellement.",
    });
  }

  const endpoint = new URL(
    "https://api.apiplaqueimmatriculation.com/plaque",
  );
  endpoint.searchParams.set("immatriculation", registration);
  endpoint.searchParams.set("token", token);
  endpoint.searchParams.set("pays", "FR");

  let providerResponse: Response;
  try {
    providerResponse = await fetch(endpoint, {
      method: "POST",
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(9000),
    });
  } catch {
    return jsonResponse(503, {
      success: false,
      error_code: "VEHICLE_LOOKUP_UNAVAILABLE",
      message:
        "Le service d’identification est temporairement indisponible. "
        + "Vous pouvez continuer manuellement.",
    });
  }

  if (providerResponse.status === 429) {
    return jsonResponse(429, {
      success: false,
      error_code: "VEHICLE_LOOKUP_RATE_LIMITED",
      message:
        "Le service d’identification reçoit trop de demandes. "
        + "Réessayez dans quelques instants.",
    });
  }

  if (!providerResponse.ok) {
    return jsonResponse(502, {
      success: false,
      error_code: "VEHICLE_LOOKUP_PROVIDER_ERROR",
      message:
        "Le service d’identification n’a pas répondu correctement. "
        + "Vous pouvez continuer manuellement.",
    });
  }

  let providerPayload: JsonRecord;
  try {
    providerPayload = await providerResponse.json() as JsonRecord;
  } catch {
    return jsonResponse(502, {
      success: false,
      error_code: "VEHICLE_LOOKUP_INVALID_RESPONSE",
      message:
        "Le service d’identification a renvoyé une réponse invalide. "
        + "Vous pouvez continuer manuellement.",
    });
  }

  const rawData = providerPayload.data;
  if (!rawData || typeof rawData !== "object" || Array.isArray(rawData)) {
    return jsonResponse(404, {
      success: false,
      error_code: "VEHICLE_NOT_FOUND",
      message:
        "Aucun véhicule n’a été trouvé pour cette immatriculation. "
        + "Complétez les informations manuellement.",
    });
  }

  const data = rawData as JsonRecord;
  const providerError = nullableText(data.erreur);

  if (providerError) {
    return jsonResponse(404, {
      success: false,
      error_code: "VEHICLE_NOT_FOUND",
      message:
        "Aucun véhicule n’a été trouvé pour cette immatriculation. "
        + "Complétez les informations manuellement.",
    });
  }

  const make = nullableText(data.marque);
  const model = nullableText(data.modele);

  if (!make || !model) {
    return jsonResponse(404, {
      success: false,
      error_code: "VEHICLE_NOT_FOUND",
      message:
        "Les informations techniques du véhicule sont insuffisantes. "
        + "Complétez-les manuellement.",
    });
  }

  return jsonResponse(200, {
    success: true,
    vehicle: {
      registration_number: registration,
      make,
      model,
      vehicle_year: parseYear(data),
      fuel_type: normalizeFuel(data.energieNGC),
      source_label: "API Plaque Immatriculation",
    },
  });
});
