import { authenticate } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROVIDER = "auto_ways_rapidapi";
const SOURCE_LABEL = "API Plaque Immatriculation";
const CACHE_MAX_AGE_MS = 365 * 24 * 60 * 60 * 1000;

type JsonRecord = Record<string, unknown>;

type StoredProfile = {
  id: string;
  registration_number: string;
  vin: string | null;
  source_label: string;
  retrieved_at: string;
  identity: JsonRecord;
  technical: JsonRecord;
  administrative: JsonRecord;
  aftersales: JsonRecord;
  media: JsonRecord;
};

const providerFieldAllowlist = [
  "AWN_KBAS",
  "AWN_id_version",
  "AWN_label_moteur",
  "AWN_code_critere_qualite_air",
  "AWN_finition",
  "AWN_tecdoc_modele_id",
  "AWN_tecdoc_marque_id",
  "AWN_genre_label",
  "AWN_genre",
  "AWN_label",
  "AWN_code_platform",
  "AWN_genre_code",
  "AWN_energie",
  "AWN_energie_cg",
  "AWN_energie_description",
  "AWN_energie_code",
  "AWN_couleur",
  "AWN_puissance_chevaux",
  "AWN_puissance_fiscale",
  "AWN_puissance_KW",
  "AWN_emission_co_2",
  "AWN_emission_co_2_prf",
  "AWN_type_reception_euro",
  "AWN_cylindre_capacite",
  "AWN_marque_carrosserie",
  "AWN_modele_code",
  "AWN_carrosserie",
  "AWN_style_carrosserie",
  "AWN_carrosserie_carte_grise",
  "AWN_carrosserie_ce",
  "AWN_type_boite_vites",
  "AWN_type_variante_version",
  "AWN_hauteur",
  "AWN_largeur",
  "AWN_longueur",
  "AWN_empattement",
  "AWN_codes_moteur",
  "AWN_PTAC_constructeur",
  "AWN_PTAC",
  "AWN_PTRA",
  "AWN_PV",
  "AWN_PTAV",
  "AWN_propulsion",
  "AWN_propulsion_label",
  "AWN_nbr_de_places",
  "AWN_nbr_soupapes",
  "AWN_nbr_volumes",
  "AWN_nbr_portes",
  "AWN_nbr_vitesses",
  "AWN_nbr_cylindres",
  "AWN_consommation_urbaine",
  "AWN_consommation_ex_urbaine",
  "AWN_consommation_mixte",
  "AWN_prix",
  "AWN_collection",
  "AWN_type_embrayage",
  "AWN_depollution",
  "AWN_vitesse_moteur",
  "AWN_style_carrosserie_code",
  "AWN_k_type",
  "AWN_k_types",
  "AWN_type_mine",
  "AWN_categorie_vehicule",
  "AWN_numero_de_serie",
  "AWN_code_moteur",
  "AWN_selector_marque_id",
  "AWN_selector_modele_id",
  "AWN_selector_modele_label",
  "AWN_immat",
  "AWN_marque",
  "AWN_version",
  "AWN_modele",
  "AWN_modele_etude",
  "AWN_date_mise_en_circulation",
  "AWN_annee_de_debut_modele",
  "AWN_annee_de_fin_modele",
  "AWN_code_de_boite_de_vitesses",
  "AWN_codes_de_boite_de_vitesses",
  "AWN_id_phase",
  "AWN_generation",
  "AWN_SRA_groupe_code",
  "AWN_segment",
  "AWN_type_anti_vol",
  "AWN_group",
  "AWN_tecdoc_modele_description",
  "AWN_niveau_de_bruit_au_ralenti",
  "AWN_KBA",
  "AWN_env_class_ref",
  "AWN_VIN",
  "AWN_turbo_compressor",
  "AWN_nbr_turbo_compressor",
  "AWN_env_class",
  "AWN_norme_euro",
  "AWN_model_image",
  "AWN_marque_image",
  "AWN_ad_blue",
  "AWN_pays",
  "AWN_type_injection",
  "AWN_mode_injection",
  "AWN_nbr_cylindre_energie",
  "AWN_classe_prix",
  "AWN_marque_code",
  "AWN_nom_commercial",
  "AWN_tecdoc_vehicule_id",
  "AWN_capacite_reservoir",
  "AWN_code_sra",
  "AWN_codes_sra",
  "AWN_date_cg",
  "AWN_numero_de_recept_euro_prf",
  "AWN_modele_prf",
  "AWN_date_mise_en_circulation_us",
  "AWN_nbr_essieux",
  "AWN_pneus",
  "AWN_max_speed",
  "AWN_mode_transmission",
  "AWN_mode_transmission_label",
  "AWN_type_transmission",
  "AWN_type_frein",
  "AWN_cylindree_liters",
  "AWN_niveau_sonore",
] as const;

function jsonResponse(status: number, body: JsonRecord): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function errorResponse(
  status: number,
  errorCode: string,
  message: string,
): Response {
  return jsonResponse(status, {
    success: false,
    error_code: errorCode,
    message,
  });
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function cleanString(value: unknown): string | null {
  if (typeof value !== "string" && typeof value !== "number") return null;
  const text = String(value).trim();
  if (!text || text.toUpperCase() === "INCONNU") return null;
  return text;
}

function firstString(data: JsonRecord, keys: string[]): string | null {
  for (const key of keys) {
    const value = cleanString(data[key]);
    if (value !== null) return value;
  }
  return null;
}

function numberValue(data: JsonRecord, keys: string[]): number | null {
  const raw = firstString(data, keys);
  if (raw === null) return null;
  const parsed = Number(raw.replace(",", "."));
  return Number.isFinite(parsed) ? parsed : null;
}

function stringArray(data: JsonRecord, keys: string[]): string[] {
  for (const key of keys) {
    const value = data[key];
    if (Array.isArray(value)) {
      return value
        .map((item) => cleanString(item))
        .filter((item): item is string => item !== null);
    }
  }
  return [];
}

function put(record: JsonRecord, key: string, value: unknown): void {
  if (value === null || value === undefined) return;
  if (typeof value === "string" && value.trim() === "") return;
  if (Array.isArray(value) && value.length === 0) return;
  record[key] = value;
}

function normalizeRegistration(value: string): string {
  return value.toUpperCase().replace(/[^A-Z0-9]/g, "");
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
  if (normalized === "EL" || normalized.includes("ELECTR")) {
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
  if (normalized.includes("HYBR")) return "Hybride";
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
  if (normalized.includes("GPL") || normalized.includes("LPG")) return "GPL";
  return "Autre";
}

function validVin(value: string | null): string | null {
  if (value === null) return null;
  const normalized = value.toUpperCase().replace(/\s/g, "");
  return /^[A-HJ-NPR-Z0-9]{17}$/.test(normalized) ? normalized : null;
}

function allowlistedProviderFields(data: JsonRecord): JsonRecord {
  const result: JsonRecord = {};
  for (const key of providerFieldAllowlist) {
    if (Object.prototype.hasOwnProperty.call(data, key)) {
      result[key] = data[key];
    }
  }
  return result;
}

function buildGroups(data: JsonRecord): {
  identity: JsonRecord;
  technical: JsonRecord;
  administrative: JsonRecord;
  aftersales: JsonRecord;
  media: JsonRecord;
} {
  const identity: JsonRecord = {};
  put(identity, "vin", validVin(firstString(data, ["AWN_VIN", "VIN", "vin"])));
  put(identity, "make", firstString(data, ["AWN_marque", "marque"]));
  put(identity, "model", firstString(data, ["AWN_modele", "modele"]));
  put(identity, "commercial_name", firstString(data, ["AWN_nom_commercial", "nom_commercial"]));
  put(identity, "full_label", firstString(data, ["AWN_label", "label"]));
  put(identity, "version", firstString(data, ["AWN_version", "version"]));
  put(identity, "trim", firstString(data, ["AWN_finition", "finition"]));
  put(identity, "model_study", firstString(data, ["AWN_modele_etude", "modele_etude"]));
  put(identity, "selector_model_label", firstString(data, ["AWN_selector_modele_label", "selector_modele_label"]));
  put(identity, "first_registration_date", firstString(data, ["AWN_date_mise_en_circulation_us", "date_mise_en_circulation_us", "AWN_date_mise_en_circulation", "date_mise_en_circulation"]));
  put(identity, "registration_certificate_date", firstString(data, ["AWN_date_cg", "date_cg"]));
  put(identity, "model_start_year", firstString(data, ["AWN_annee_de_debut_modele", "annee_de_debut_modele"]));
  put(identity, "model_end_year", firstString(data, ["AWN_annee_de_fin_modele", "annee_de_fin_modele"]));
  put(identity, "phase", firstString(data, ["AWN_id_phase", "id_phase"]));
  put(identity, "generation", firstString(data, ["AWN_generation", "generation"]));
  put(identity, "platform_code", firstString(data, ["AWN_code_platform", "code_platform"]));
  put(identity, "color", firstString(data, ["AWN_couleur", "couleur"]));

  const technical: JsonRecord = {};
  put(technical, "energy", firstString(data, ["AWN_energie_description", "AWN_energie", "energie"]));
  put(technical, "energy_code", firstString(data, ["AWN_energie_cg", "energie_cg"]));
  put(technical, "power_kw", numberValue(data, ["AWN_puissance_KW", "puissance_KW"]));
  put(technical, "horsepower", numberValue(data, ["AWN_puissance_chevaux", "puissance_chevaux"]));
  put(technical, "fiscal_power", numberValue(data, ["AWN_puissance_fiscale", "puissance_fiscale"]));
  put(technical, "engine_label", firstString(data, ["AWN_label_moteur", "label_moteur"]));
  put(technical, "engine_code", firstString(data, ["AWN_code_moteur", "code_moteur"]));
  put(technical, "engine_codes", stringArray(data, ["AWN_codes_moteur", "codes_moteur"]));
  put(technical, "cylinder_capacity_cm3", numberValue(data, ["AWN_cylindre_capacite", "cylindre_capacite"]));
  put(technical, "displacement_l", numberValue(data, ["AWN_cylindree_liters", "cylindree_liters"]));
  put(technical, "cylinders", numberValue(data, ["AWN_nbr_cylindres", "nbr_cylindres"]));
  put(technical, "valves", numberValue(data, ["AWN_nbr_soupapes", "nbr_soupapes"]));
  put(technical, "gearbox_type", firstString(data, ["AWN_type_boite_vites", "type_boite_vites"]));
  put(technical, "gearbox_code", firstString(data, ["AWN_code_de_boite_de_vitesses", "code_de_boite_de_vitesses"]));
  put(technical, "gearbox_codes", stringArray(data, ["AWN_codes_de_boite_de_vitesses", "codes_de_boite_de_vitesses"]));
  put(technical, "gears", numberValue(data, ["AWN_nbr_vitesses", "nbr_vitesses"]));
  put(technical, "transmission_type", firstString(data, ["AWN_type_transmission", "type_transmission"]));
  put(technical, "transmission_mode", firstString(data, ["AWN_mode_transmission_label", "mode_transmission_label", "AWN_mode_transmission", "mode_transmission"]));
  put(technical, "propulsion", firstString(data, ["AWN_propulsion_label", "propulsion_label", "AWN_propulsion", "propulsion"]));
  put(technical, "body_style", firstString(data, ["AWN_style_carrosserie", "style_carrosserie", "AWN_carrosserie", "carrosserie"]));
  put(technical, "bodywork_national", firstString(data, ["AWN_carrosserie_carte_grise", "carrosserie_carte_grise"]));
  put(technical, "bodywork_ce", firstString(data, ["AWN_carrosserie_ce", "carrosserie_ce"]));
  put(technical, "seats", numberValue(data, ["AWN_nbr_de_places", "nbr_de_places"]));
  put(technical, "doors", numberValue(data, ["AWN_nbr_portes", "nbr_portes"]));
  put(technical, "length_cm", numberValue(data, ["AWN_longueur", "longueur"]));
  put(technical, "width_cm", numberValue(data, ["AWN_largeur", "largeur"]));
  put(technical, "height_cm", numberValue(data, ["AWN_hauteur", "hauteur"]));
  put(technical, "wheelbase_cm", numberValue(data, ["AWN_empattement", "empattement"]));
  put(technical, "ptac_kg", numberValue(data, ["AWN_PTAC", "PTAC"]));
  put(technical, "ptac_manufacturer_kg", numberValue(data, ["AWN_PTAC_constructeur", "PTAC_constructeur"]));
  put(technical, "ptra_kg", numberValue(data, ["AWN_PTRA", "PTRA"]));
  put(technical, "service_weight_kg", numberValue(data, ["AWN_PV", "PV"]));
  put(technical, "empty_weight_kg", numberValue(data, ["AWN_PTAV", "PTAV"]));
  put(technical, "max_speed_kmh", numberValue(data, ["AWN_max_speed", "max_speed"]));
  put(technical, "tank_capacity_l", numberValue(data, ["AWN_capacite_reservoir", "capacite_reservoir"]));
  put(technical, "tyres", stringArray(data, ["AWN_pneus", "pneus"]));
  put(technical, "co2_g_km", numberValue(data, ["AWN_emission_co_2", "emission_co_2"]));
  put(technical, "euro_standard", firstString(data, ["AWN_norme_euro", "norme_euro"]));
  put(technical, "environment_class", firstString(data, ["AWN_env_class", "env_class"]));
  put(technical, "critair_code", firstString(data, ["AWN_code_critere_qualite_air", "code_critere_qualite_air"]));
  put(technical, "consumption_urban", numberValue(data, ["AWN_consommation_urbaine", "consommation_urbaine"]));
  put(technical, "consumption_extra_urban", numberValue(data, ["AWN_consommation_ex_urbaine", "consommation_ex_urbaine"]));
  put(technical, "consumption_mixed", numberValue(data, ["AWN_consommation_mixte", "consommation_mixte"]));
  put(technical, "adblue", firstString(data, ["AWN_ad_blue", "ad_blue"]));

  const administrative: JsonRecord = {};
  put(administrative, "vehicle_category", firstString(data, ["AWN_categorie_vehicule", "categorie_vehicule"]));
  put(administrative, "genre", firstString(data, ["AWN_genre", "genre"]));
  put(administrative, "genre_label", firstString(data, ["AWN_genre_label", "genre_label"]));
  put(administrative, "country", firstString(data, ["AWN_pays", "pays"]));
  put(administrative, "type_mine", firstString(data, ["AWN_type_mine", "type_mine"]));
  put(administrative, "type_variant_version", firstString(data, ["AWN_type_variante_version", "type_variante_version"]));
  put(administrative, "european_approval", firstString(data, ["AWN_numero_de_recept_euro_prf", "numero_de_recept_euro_prf"]));
  put(administrative, "reception_type", firstString(data, ["AWN_type_reception_euro", "type_reception_euro"]));
  put(administrative, "serial_number", firstString(data, ["AWN_numero_de_serie", "numero_de_serie"]));
  put(administrative, "collection", firstString(data, ["AWN_collection", "collection"]));
  put(administrative, "axles", numberValue(data, ["AWN_nbr_essieux", "nbr_essieux"]));

  const aftersales: JsonRecord = {};
  put(aftersales, "k_type", firstString(data, ["AWN_k_type", "k_type"]));
  put(aftersales, "k_types", stringArray(data, ["AWN_k_types", "k_types"]));
  put(aftersales, "sra_code", firstString(data, ["AWN_code_sra", "code_sra"]));
  put(aftersales, "sra_codes", stringArray(data, ["AWN_codes_sra", "codes_sra"]));
  put(aftersales, "sra_group_code", firstString(data, ["AWN_SRA_groupe_code", "SRA_groupe_code"]));
  put(aftersales, "kba", firstString(data, ["AWN_KBA", "KBA"]));
  put(aftersales, "kbas", stringArray(data, ["AWN_KBAS", "KBAS"]));
  put(aftersales, "tecdoc_brand_id", firstString(data, ["AWN_tecdoc_marque_id", "tecdoc_marque_id"]));
  put(aftersales, "tecdoc_model_id", firstString(data, ["AWN_tecdoc_modele_id", "tecdoc_modele_id"]));
  put(aftersales, "tecdoc_vehicle_id", firstString(data, ["AWN_tecdoc_vehicule_id", "tecdoc_vehicule_id"]));
  put(aftersales, "tecdoc_model_description", firstString(data, ["AWN_tecdoc_modele_description", "tecdoc_modele_description"]));
  put(aftersales, "selector_brand_id", firstString(data, ["AWN_selector_marque_id", "selector_marque_id"]));
  put(aftersales, "selector_model_id", firstString(data, ["AWN_selector_modele_id", "selector_modele_id"]));
  put(aftersales, "brand_code", firstString(data, ["AWN_marque_code", "marque_code"]));
  put(aftersales, "model_code", firstString(data, ["AWN_modele_code", "modele_code"]));
  put(aftersales, "version_id", firstString(data, ["AWN_id_version", "id_version"]));
  put(aftersales, "segment", firstString(data, ["AWN_segment", "segment"]));
  put(aftersales, "manufacturer_group", firstString(data, ["AWN_group", "group"]));
  put(aftersales, "price_class", firstString(data, ["AWN_classe_prix", "classe_prix"]));
  put(aftersales, "catalog_reference_price", numberValue(data, ["AWN_prix", "prix"]));
  put(aftersales, "anti_theft_type", firstString(data, ["AWN_type_anti_vol", "type_anti_vol"]));
  put(aftersales, "injection_type", firstString(data, ["AWN_type_injection", "type_injection"]));
  put(aftersales, "injection_mode", firstString(data, ["AWN_mode_injection", "mode_injection"]));
  put(aftersales, "clutch_type", firstString(data, ["AWN_type_embrayage", "type_embrayage"]));
  put(aftersales, "brake_type", firstString(data, ["AWN_type_frein", "type_frein"]));
  put(aftersales, "turbo_type", firstString(data, ["AWN_turbo_compressor", "turbo_compressor"]));
  put(aftersales, "turbo_count", firstString(data, ["AWN_nbr_turbo_compressor", "nbr_turbo_compressor"]));

  const media: JsonRecord = {};
  put(media, "brand_image_url", firstString(data, ["AWN_marque_image", "marque_image"]));
  put(media, "model_image_url", firstString(data, ["AWN_model_image", "model_image"]));

  return { identity, technical, administrative, aftersales, media };
}

function vehiclePayload(profile: StoredProfile, cached: boolean): JsonRecord {
  const identity = profile.identity ?? {};
  const technical = profile.technical ?? {};
  const make = cleanString(identity["make"]);
  const model = cleanString(identity["model"]);
  const firstRegistrationDate = cleanString(identity["first_registration_date"]);
  let year: number | null = null;
  if (firstRegistrationDate !== null) {
    const match = /^([0-9]{4})/.exec(firstRegistrationDate) ?? /([0-9]{4})$/.exec(firstRegistrationDate);
    if (match !== null) year = validYear(Number(match[1]));
  }
  const fuelType = normalizeFuel(cleanString(technical["energy"]));

  return {
    registration_number: profile.registration_number,
    make: make ?? "",
    model: model ?? "",
    vehicle_year: year,
    fuel_type: fuelType,
    vin: profile.vin,
    first_registration_date: firstRegistrationDate,
    source_label: profile.source_label,
    profile_id: profile.id,
    retrieved_at: profile.retrieved_at,
    cached,
    details: {
      identity: profile.identity,
      technical: profile.technical,
      administrative: profile.administrative,
      aftersales: profile.aftersales,
      media: profile.media,
    },
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "METHOD_NOT_ALLOWED", "Methode non autorisee.");
  }

  let auth;
  try {
    auth = await authenticate(req);
  } catch (_) {
    return errorResponse(401, "AUTH_REQUIRED", "Votre session a expire. Reconnectez-vous.");
  }

  const providerToken = Deno.env.get("API_PLAQUE_IMMATRICULATION_TOKEN")?.trim();
  if (!providerToken) {
    return errorResponse(503, "VEHICLE_LOOKUP_NOT_CONFIGURED", "Identification automatique indisponible. Vous pouvez continuer manuellement.");
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch (_) {
    return errorResponse(400, "INVALID_REQUEST", "Requete invalide.");
  }
  if (!isRecord(body)) {
    return errorResponse(400, "INVALID_REQUEST", "Requete invalide.");
  }

  const requestedRegistration = firstString(body, ["registration_number", "registration", "plaque"]);
  if (requestedRegistration === null) {
    return errorResponse(400, "VEHICLE_REGISTRATION_INVALID", "Immatriculation requise.");
  }

  const compactRegistration = normalizeRegistration(requestedRegistration);
  if (compactRegistration.length < 5 || compactRegistration.length > 12) {
    return errorResponse(400, "VEHICLE_REGISTRATION_INVALID", "Format d'immatriculation invalide.");
  }

  const forceRefresh = body["force_refresh"] === true;
  if (!forceRefresh) {
    const { data: cachedProfile, error: cacheError } = await auth.adminClient
      .from("vehicle_identification_profiles")
      .select("id,registration_number,vin,source_label,retrieved_at,identity,technical,administrative,aftersales,media")
      .eq("user_id", auth.user.id)
      .eq("registration_key", compactRegistration)
      .eq("provider", PROVIDER)
      .maybeSingle();

    if (!cacheError && cachedProfile) {
      const retrievedAt = Date.parse(cachedProfile.retrieved_at);
      if (Number.isFinite(retrievedAt) && Date.now() - retrievedAt <= CACHE_MAX_AGE_MS) {
        return jsonResponse(200, {
          success: true,
          vehicle: vehiclePayload(cachedProfile as StoredProfile, true),
        });
      }
    }
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
        "x-rapidapi-host": "api-de-plaque-d-immatriculation-france.p.rapidapi.com",
        "x-rapidapi-key": providerToken,
      },
      signal: AbortSignal.timeout(9000),
    });
  } catch (_) {
    return errorResponse(503, "VEHICLE_LOOKUP_UNAVAILABLE", "Le service d'identification est temporairement indisponible. Vous pouvez continuer manuellement.");
  }

  let providerPayload: unknown;
  try {
    providerPayload = await providerResponse.json();
  } catch (_) {
    return errorResponse(502, "VEHICLE_LOOKUP_INVALID_RESPONSE", "Le service d'identification a retourne une reponse invalide. Vous pouvez continuer manuellement.");
  }
  if (!isRecord(providerPayload)) {
    return errorResponse(502, "VEHICLE_LOOKUP_INVALID_RESPONSE", "Le service d'identification a retourne une reponse invalide. Vous pouvez continuer manuellement.");
  }

  const providerCode = Number(providerPayload["code"]);
  const providerError = providerPayload["error"] === true;
  if (!providerResponse.ok || providerError || (Number.isFinite(providerCode) && providerCode !== 200)) {
    const notFound = providerResponse.status === 404 || providerCode === 404;
    return errorResponse(
      notFound ? 404 : 503,
      notFound ? "VEHICLE_NOT_FOUND" : "VEHICLE_LOOKUP_UNAVAILABLE",
      notFound
        ? "Aucun vehicule n'a ete identifie avec cette immatriculation. Vous pouvez continuer manuellement."
        : "Le service d'identification est temporairement indisponible. Vous pouvez continuer manuellement.",
    );
  }

  const data = providerPayload["data"];
  if (!isRecord(data)) {
    return errorResponse(502, "VEHICLE_LOOKUP_INVALID_RESPONSE", "Le service d'identification a retourne une reponse incomplete. Vous pouvez continuer manuellement.");
  }

  const make = firstString(data, ["AWN_marque", "marque"]);
  const model = firstString(data, ["AWN_modele", "modele", "AWN_nom_commercial", "nom_commercial"]);
  if (make === null || model === null) {
    return errorResponse(422, "VEHICLE_IDENTIFICATION_INCOMPLETE", "Le vehicule a ete trouve mais son identification est incomplete. Vous pouvez continuer manuellement.");
  }

  const groups = buildGroups(data);
  groups.identity["make"] = make;
  groups.identity["model"] = model;
  const vin = validVin(firstString(data, ["AWN_VIN", "VIN", "vin"]));
  const retrievedAt = new Date().toISOString();

  let linkedVehicleId: string | null = null;
  const { data: userVehicles } = await auth.adminClient
    .from("vehicles")
    .select("id,registration_number")
    .eq("user_id", auth.user.id);
  if (Array.isArray(userVehicles)) {
    const match = userVehicles.find((item) =>
      normalizeRegistration(String(item.registration_number ?? "")) === compactRegistration
    );
    linkedVehicleId = match?.id?.toString() ?? null;
  }

  const profileRow = {
    user_id: auth.user.id,
    vehicle_id: linkedVehicleId,
    registration_number: plate,
    registration_key: compactRegistration,
    vin,
    provider: PROVIDER,
    source_label: SOURCE_LABEL,
    retrieved_at: retrievedAt,
    identity: groups.identity,
    technical: groups.technical,
    administrative: groups.administrative,
    aftersales: groups.aftersales,
    media: groups.media,
    provider_fields: allowlistedProviderFields(data),
    updated_at: retrievedAt,
  };

  const { data: savedProfile, error: saveError } = await auth.adminClient
    .from("vehicle_identification_profiles")
    .upsert(profileRow, { onConflict: "user_id,registration_key,provider" })
    .select("id,registration_number,vin,source_label,retrieved_at,identity,technical,administrative,aftersales,media")
    .single();

  if (saveError || !savedProfile) {
    return errorResponse(500, "VEHICLE_PROFILE_SAVE_FAILED", "Le vehicule a ete identifie mais ses caracteristiques n'ont pas pu etre enregistrees. Reessayez plus tard.");
  }

  const payload = vehiclePayload(savedProfile as StoredProfile, false);
  payload["vehicle_year"] = parseYear(data);
  payload["fuel_type"] = normalizeFuel(firstString(data, ["AWN_energie_description", "AWN_energie", "energie", "AWN_energie_cg", "energie_cg"]));
  payload["vin"] = vin;

  return jsonResponse(200, {
    success: true,
    vehicle: payload,
  });
});
