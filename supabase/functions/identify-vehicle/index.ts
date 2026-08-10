const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonRecord = Record<string, unknown>;

function jsonResponse(status: number, body: JsonRecord): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function cleanString(value: unknown): string | null {
  if (typeof value !== "string" && typeof value !== "number") {
    return null;
  }

  const text = String(value).trim();
  if (!text || text.toUpperCase() === "INCONNU") {
    return null;
  }

  return text;
}

function firstString(data: JsonRecord, keys: string[]): string | null {
  for (const key of keys) {
    const value = cleanString(data[key]);
    if (value !== null) {
      return value;
    }
  }
  return null;
}

function normalizeRegistration(value: string): string {
  return value
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");
}

function providerRegistration(compact: string): string {
  if (/^[A-Z]{2}[0-9]{3}[A-Z]{2}$/.test(compact)) {
    return `${compact.substring(0, 2)}-${compact.substring(2, 5)}-${
      compact.substring(5, 7)
    }`;
  }

  return compact;
}

function validYear(value: number): number | null {
  const maximum = new Date().getUTCFullYear() + 1;
  return Number.isInteger(value) && value >= 1886 && value <= maximum
    ? value
    : null;
}

function parseYear(data: JsonRecord): number | null {
  const usDate = firstString(data, [
    "AWN_date_mise_en_circulation_us",
    "date_mise_en_circulation_us",
  ]);

  if (usDate !== null) {
    const match = /^([0-9]{4})-[0-9]{2}-[0-9]{2}$/.exec(usDate);
    if (match !== null) {
      const year = validYear(Number(match[1]));
      if (year !== null) return year;
    }
  }

  const frenchDate = firstString(data, [
    "AWN_date_mise_en_circulation",
    "date_mise_en_circulation",
    "AWN_date_cg",
    "date_cg",
  ]);

  if (frenchDate !== null) {
    const match = /([0-9]{4})$/.exec(frenchDate);
    if (match !== null) {
      const year = validYear(Number(match[1]));
      if (year !== null) return year;
    }
  }

  const modelYear = firstString(data, [
    "AWN_annee_de_debut_modele",
    "annee_de_debut_modele",
  ]);

  if (modelYear !== null && /^[0-9]{4}$/.test(modelYear)) {
    return validYear(Number(modelYear));
  }

  return null;
}

function fold(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toUpperCase()
    .trim();
}

function normalizeFuel(value: string | null): string | null {
  if (value === null) return null;

  const normalized = fold(value);
  if (!normalized || normalized === "INCONNU") return null;

  if (
    normalized === "EL" ||
    normalized.includes("ELECTR")
  ) {
    return "Électrique";
  }

  if (
    normalized.includes("HYBR") &&
    (normalized.includes("RECHARG") ||
      normalized.includes("PLUG") ||
      normalized.includes("PHEV"))
  ) {
    return "Hybride rechargeable";
  }

  if (normalized.includes("HYBR")) {
    return "Hybride";
  }

  if (
    normalized === "GO" ||
    normalized.includes("GAZOLE") ||
    normalized.includes("DIESEL")
  ) {
    return "Diesel";
  }

  if (
    normalized === "ES" ||
    normalized.includes("ESSENCE") ||
    normalized.includes("GASOLINE") ||
    normalized.includes("PETROL")
  ) {
    return "Essence";
  }

  if (normalized.includes("GPL") || normalized.includes("LPG")) {
    return "GPL";
  }

  return "Autre";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      error: "METHOD_NOT_ALLOWED",
      message: "Methode non autorisee.",
    });
  }

  const providerToken = Deno.env.get(
    "API_PLAQUE_IMMATRICULATION_TOKEN",
  )?.trim();

  if (!providerToken) {
    return jsonResponse(503, {
      error: "PROVIDER_NOT_CONFIGURED",
      message:
        "Identification automatique indisponible. Vous pouvez continuer manuellement.",
    });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse(400, {
      error: "INVALID_REQUEST",
      message: "Requete invalide.",
    });
  }

  if (!isRecord(body)) {
    return jsonResponse(400, {
      error: "INVALID_REQUEST",
      message: "Requete invalide.",
    });
  }

  const requestedRegistration = firstString(body, [
    "registration_number",
    "registration",
    "plaque",
  ]);

  if (requestedRegistration === null) {
    return jsonResponse(400, {
      error: "REGISTRATION_REQUIRED",
      message: "Immatriculation requise.",
    });
  }

  const compactRegistration = normalizeRegistration(
    requestedRegistration,
  );

  if (
    compactRegistration.length < 5 ||
    compactRegistration.length > 12
  ) {
    return jsonResponse(400, {
      error: "INVALID_REGISTRATION",
      message: "Format d'immatriculation invalide.",
    });
  }

  const plate = providerRegistration(compactRegistration);
  const providerUrl =
    "https://api-de-plaque-d-immatriculation-france.p.rapidapi.com/" +
    `?plaque=${encodeURIComponent(plate)}`;

  let providerResponse: Response;
  try {
    providerResponse = await fetch(providerUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "plaque": plate,
        "x-rapidapi-host":
          "api-de-plaque-d-immatriculation-france.p.rapidapi.com",
        "x-rapidapi-key": providerToken,
      },
    });
  } catch (_) {
    return jsonResponse(503, {
      error: "PROVIDER_UNAVAILABLE",
      message:
        "Le service d'identification est temporairement indisponible. Vous pouvez continuer manuellement.",
    });
  }

  let providerPayload: unknown;
  try {
    providerPayload = await providerResponse.json();
  } catch (_) {
    return jsonResponse(502, {
      error: "INVALID_PROVIDER_RESPONSE",
      message:
        "Le service d'identification a retourne une reponse invalide. Vous pouvez continuer manuellement.",
    });
  }

  if (!isRecord(providerPayload)) {
    return jsonResponse(502, {
      error: "INVALID_PROVIDER_RESPONSE",
      message:
        "Le service d'identification a retourne une reponse invalide. Vous pouvez continuer manuellement.",
    });
  }

  const providerCode = Number(providerPayload["code"]);
  const providerError = providerPayload["error"] === true;

  if (
    !providerResponse.ok ||
    providerError ||
    (Number.isFinite(providerCode) && providerCode !== 200)
  ) {
    const notFound =
      providerResponse.status === 404 || providerCode === 404;

    return jsonResponse(notFound ? 404 : 503, {
      error: notFound ? "VEHICLE_NOT_FOUND" : "PROVIDER_UNAVAILABLE",
      message: notFound
        ? "Aucun vehicule n'a ete identifie avec cette immatriculation. Vous pouvez continuer manuellement."
        : "Le service d'identification est temporairement indisponible. Vous pouvez continuer manuellement.",
    });
  }

  const data = providerPayload["data"];
  if (!isRecord(data)) {
    return jsonResponse(502, {
      error: "INVALID_PROVIDER_RESPONSE",
      message:
        "Le service d'identification a retourne une reponse incomplete. Vous pouvez continuer manuellement.",
    });
  }

  const make = firstString(data, [
    "AWN_marque",
    "marque",
  ]);

  const model = firstString(data, [
    "AWN_modele",
    "modele",
    "AWN_nom_commercial",
    "nom_commercial",
  ]);

  const vehicleYear = parseYear(data);

  const fuelType = normalizeFuel(
    firstString(data, [
      "AWN_energie_description",
      "AWN_energie",
      "energie",
      "AWN_energie_cg",
      "energie_cg",
    ]),
  );

  if (make === null || model === null) {
    return jsonResponse(422, {
      error: "IDENTIFICATION_INCOMPLETE",
      message:
        "Le vehicule a ete trouve mais son identification est incomplete. Vous pouvez continuer manuellement.",
    });
  }

  return jsonResponse(200, {
    registration_number: plate,
    make,
    model,
    vehicle_year: vehicleYear,
    fuel_type: fuelType,
  });
});
