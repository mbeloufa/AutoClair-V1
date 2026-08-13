import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const OPENAI_MODEL = "gpt-5.6-terra";
const CACHE_DAYS_READY = 365;
const CACHE_DAYS_UNAVAILABLE = 90;

const officialDomains: Record<string, string[]> = {
  volkswagen: ["volkswagen.fr", "volkswagen.de"],
  vw: ["volkswagen.fr", "volkswagen.de"],
  audi: ["audi.fr"],
  skoda: ["skoda.fr"],
  seat: ["seat.fr"],
  cupra: ["cupraofficial.fr"],
  renault: ["renault.fr"],
  dacia: ["dacia.fr"],
  peugeot: ["peugeot.fr"],
  citroen: ["citroen.fr"],
  "citroën": ["citroen.fr"],
  ds: ["dsautomobiles.fr"],
  bmw: ["bmw.fr"],
  mini: ["mini.fr"],
  mercedes: ["mercedes-benz.fr"],
  "mercedes-benz": ["mercedes-benz.fr"],
  opel: ["opel.fr"],
  ford: ["ford.fr"],
  fiat: ["fiat.fr"],
  abarth: ["abarth.fr"],
  "alfa romeo": ["alfaromeo.fr"],
  jeep: ["jeep.fr"],
  toyota: ["toyota.fr"],
  lexus: ["lexus.fr"],
  nissan: ["nissan.fr"],
  honda: ["honda.fr"],
  hyundai: ["hyundai.com"],
  kia: ["kia.com"],
  mazda: ["mazda.fr"],
  suzuki: ["suzuki.fr"],
  volvo: ["volvocars.com"],
  porsche: ["porsche.com"],
  tesla: ["tesla.com"],
  "land rover": ["landrover.fr"],
  jaguar: ["jaguar.fr"],
  mitsubishi: ["mitsubishi-motors.fr"],
  mg: ["mgmotor.fr"],
  byd: ["byd.com"],
  subaru: ["subaru.fr"],
};

const allowedProfileKeys = new Set([
  "version", "trim", "finition", "designation", "generation", "engine",
  "engine_code", "code_moteur", "codes_moteur", "k_type", "k-type",
  "ktype", "tecdoc", "model_id", "power", "puissance", "power_kw", "kw",
  "hp", "transmission", "boite", "gearbox", "displacement", "cylindree",
  "fuel", "carburant", "variant", "type", "series", "gamme",
]);

const forbiddenKeyFragments = [
  "vin", "immat", "registration", "plate", "owner", "holder", "titulaire",
  "address", "adresse", "phone", "telephone", "email", "name", "nom", "sra",
];

const schema = {
  type: "object",
  additionalProperties: false,
  properties: {
    status: { type: "string", enum: ["READY", "UNAVAILABLE"] },
    source_quality: {
      type: "string",
      enum: ["OFFICIAL_EXACT", "OFFICIAL_GENERAL", "UNAVAILABLE"],
    },
    vehicle_match_summary: { type: "string" },
    summary: { type: "string" },
    rules: {
      type: "array",
      maxItems: 18,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          rule_key: { type: "string" },
          operation_key: {
            type: "string",
            enum: [
              "SERVICE", "ENGINE_OIL", "OIL_FILTER", "BRAKE_FLUID",
              "CABIN_FILTER", "AIR_FILTER", "FUEL_FILTER", "SPARK_PLUGS",
              "TIMING_BELT", "ACCESSORY_BELT", "COOLANT", "TRANSMISSION_OIL", "OTHER",
            ],
          },
          title: { type: "string" },
          interval_km: { type: ["integer", "null"] },
          interval_months: { type: ["integer", "null"] },
          first_due_km: { type: ["integer", "null"] },
          first_due_months: { type: ["integer", "null"] },
          confidence: { type: "string", enum: ["HIGH", "MEDIUM"] },
          source_domain: { type: "string" },
          source_title_hint: { type: "string" },
          applicability_notes: { type: "string" },
          benefit: { type: "string" },
        },
        required: [
          "rule_key", "operation_key", "title", "interval_km",
          "interval_months", "first_due_km", "first_due_months", "confidence",
          "source_domain", "source_title_hint", "applicability_notes", "benefit",
        ],
      },
    },
  },
  required: ["status", "source_quality", "vehicle_match_summary", "summary", "rules"],
};
type SourceRef = { url: string; title: string; domain: string };
type Rule = {
  rule_key: string;
  operation_key: string;
  title: string;
  interval_km: number | null;
  interval_months: number | null;
  first_due_km: number | null;
  first_due_months: number | null;
  confidence: "HIGH" | "MEDIUM";
  source_domain: string;
  source_title_hint: string;
  applicability_notes: string;
  benefit: string;
};
function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizedMake(value: unknown): string {
  return String(value ?? "").trim().toLowerCase().replace(/\s+/g, " ");
}

function looksSensitive(value: string): boolean {
  const compact = value.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
  if (/^[A-HJ-NPR-Z0-9]{17}$/.test(compact)) return true;
  if (/^[A-Z]{2}\d{3}[A-Z]{2}$/.test(compact)) return true;
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())) return true;
  if (/\+?\d[\d .()-]{8,}/.test(value)) return true;
  return false;
}

function sanitizeProfile(value: unknown, depth = 0): unknown {
  if (depth > 4 || value == null) return null;
  if (Array.isArray(value)) {
    return value.slice(0, 20).map((item) => sanitizeProfile(item, depth + 1));
  }
  if (typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [rawKey, rawValue] of Object.entries(value as Record<string, unknown>)) {
      const key = rawKey.toLowerCase();
      if (forbiddenKeyFragments.some((fragment) => key.includes(fragment))) continue;
      if (!allowedProfileKeys.has(key) && depth > 0) continue;
      const cleaned = sanitizeProfile(rawValue, depth + 1);
      if (cleaned !== null && cleaned !== "") out[rawKey] = cleaned;
    }
    return out;
  }
  if (typeof value === "string") {
    const text = value.trim().slice(0, 180);
    return looksSensitive(text) ? null : text;
  }
  if (typeof value === "number" || typeof value === "boolean") return value;
  return null;
}

function stableStringify(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => a.localeCompare(b));
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${stableStringify(v)}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

async function sha256(value: unknown): Promise<string> {
  const bytes = new TextEncoder().encode(stableStringify(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function hostAllowed(url: string, domains: string[]): boolean {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return domains.some((domain) => host === domain || host.endsWith(`.${domain}`));
  } catch (_) {
    return false;
  }
}

function sourceDomain(url: string): string {
  try {
    return new URL(url).hostname.toLowerCase().replace(/^www\./, "");
  } catch (_) {
    return "";
  }
}

function collectSources(response: any, domains: string[]): SourceRef[] {
  const values: SourceRef[] = [];
  const add = (url: unknown, title: unknown) => {
    if (typeof url !== "string" || !hostAllowed(url, domains)) return;
    if (!/^https?:\/\//i.test(url)) return;
    values.push({
      url,
      title: typeof title === "string" && title.trim() ? title.trim() : sourceDomain(url),
      domain: sourceDomain(url),
    });
  };
  for (const item of response?.output ?? []) {
    if (item?.type === "web_search_call") {
      for (const source of item?.action?.sources ?? []) add(source?.url, source?.title);
    }
    if (item?.type === "message") {
      for (const content of item?.content ?? []) {
        for (const annotation of content?.annotations ?? []) {
          if (annotation?.type === "url_citation") add(annotation?.url, annotation?.title);
        }
      }
    }
  }
  const unique = new Map<string, SourceRef>();
  for (const source of values) unique.set(source.url, source);
  return Array.from(unique.values()).slice(0, 20);
}

function outputText(response: any): string | null {
  if (typeof response?.output_text === "string" && response.output_text.trim()) {
    return response.output_text.trim();
  }
  for (const item of response?.output ?? []) {
    if (item?.type !== "message") continue;
    for (const content of item?.content ?? []) {
      if (content?.type === "output_text" && typeof content?.text === "string") {
        return content.text.trim();
      }
    }
  }
  return null;
}

function addMonths(dateText: string, months: number): string {
  const base = new Date(`${dateText.slice(0, 10)}T12:00:00Z`);
  const day = base.getUTCDate();
  const target = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth() + months, 1, 12));
  const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0, 12)).getUTCDate();
  target.setUTCDate(Math.min(day, lastDay));
  return target.toISOString().slice(0, 10);
}

function daysUntil(dateText: string | null): number | null {
  if (!dateText) return null;
  const due = Date.parse(`${dateText}T12:00:00Z`);
  if (!Number.isFinite(due)) return null;
  return Math.floor((due - Date.now()) / 86400000);
}

function normalizedEventText(event: any): string {
  return `${event?.event_type ?? ""} ${event?.title ?? ""}`
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}
function operationTerms(): Record<string, string[]> {
  return {
    SERVICE: ["revision", "entretien", "service"],
    ENGINE_OIL: ["vidange", "huile moteur"],
    OIL_FILTER: ["filtre huile", "filtre a huile"],
    BRAKE_FLUID: ["liquide frein", "liquide de frein"],
    CABIN_FILTER: ["habitacle", "pollen"],
    AIR_FILTER: ["filtre air", "filtre a air"],
    FUEL_FILTER: ["filtre carburant", "filtre gazole", "filtre diesel"],
    SPARK_PLUGS: ["bougie"],
    TIMING_BELT: ["distribution", "courroie distribution"],
    ACCESSORY_BELT: ["courroie accessoire", "courroie accessoires"],
    COOLANT: ["refroidissement", "liquide refroidissement"],
    TRANSMISSION_OIL: ["vidange boite", "huile boite", "transmission", "dsg"],
    CLIMATE: ["climatisation", "recharge clim", "air conditionne"],
    OTHER: [],
  };
}
function operationMatches(operation: string, event: any): boolean {
  const text = normalizedEventText(event);
  return (operationTerms()[operation] ?? []).some((term) => text.includes(term));
}
function buildMaintenanceHistory(events: any[]): any[] {
  const keys = [
    "ENGINE_OIL", "OIL_FILTER", "BRAKE_FLUID", "CABIN_FILTER", "AIR_FILTER",
    "FUEL_FILTER", "SPARK_PLUGS", "TIMING_BELT", "ACCESSORY_BELT", "COOLANT",
    "TRANSMISSION_OIL", "CLIMATE", "SERVICE",
  ];
  const rows: any[] = [];
  for (const event of events) {
    for (const operationKey of keys) {
      if (!operationMatches(operationKey, event)) continue;
      const mileage = event?.mileage == null ? null : Number(event.mileage);
      rows.push({
        operation_key: operationKey,
        occurred_at: String(event?.occurred_at ?? "").slice(0, 10),
        mileage: Number.isFinite(mileage) ? Math.round(mileage) : null,
      });
      if (rows.length >= 80) return rows;
    }
  }
  return rows;
}
function isRoutineCheckOnlyTitle(title: string): boolean {
  const text = title.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const excluded = [
    "liaison au sol", "liaisons au sol", "eclairage", "niveau des liquides", "niveaux",
    "pression des pneus", "pression pneus", "controle visuel", "inspection visuelle",
    "essuie glace", "essuie-glace", "controle pneus", "controle freinage", "climatisation",
  ];
  return excluded.some((term) => text.includes(term));
}
function benefitFor(rule: Rule): string {
  const proposed = String(rule.benefit ?? "").replace(/\s+/g, " ").trim().slice(0, 180);
  if (proposed.length >= 20 && !looksSensitive(proposed)) return proposed;
  const fallback: Record<string, string> = {
    SERVICE: "Respecter les révisions aide à préserver la fiabilité du véhicule et à détecter plus tôt les anomalies courantes.",
    ENGINE_OIL: "Une huile entretenue au bon intervalle aide à protéger les pièces internes du moteur contre l’usure.",
    OIL_FILTER: "Un filtre à huile entretenu aide à limiter la circulation d’impuretés dans le moteur.",
    BRAKE_FLUID: "Le liquide de frein vieillit avec le temps ; son entretien contribue à conserver un freinage régulier.",
    CABIN_FILTER: "Un filtre habitacle entretenu aide à conserver un bon débit d’air et à limiter les particules dans l’habitacle.",
    AIR_FILTER: "Un filtre à air entretenu aide le moteur à recevoir un débit d’air adapté.",
    FUEL_FILTER: "Un filtre carburant entretenu aide à protéger le circuit d’alimentation contre les impuretés.",
    SPARK_PLUGS: "Des bougies entretenues contribuent à un allumage régulier sur les moteurs qui en sont équipés.",
    TIMING_BELT: "Respecter l’échéance de distribution réduit le risque de défaillance d’un organe essentiel du moteur.",
    ACCESSORY_BELT: "Une courroie d’accessoires entretenue limite le risque de perte des équipements qu’elle entraîne.",
    COOLANT: "Un liquide de refroidissement entretenu aide le moteur et son circuit thermique à fonctionner dans de bonnes conditions.",
    TRANSMISSION_OIL: "Lorsque le constructeur le prévoit, l’entretien de la transmission aide à préserver son fonctionnement régulier.",
    OTHER: "Respecter cette opération lorsqu’elle est prévue par le constructeur aide à préserver le bon fonctionnement du véhicule.",
  };
  return fallback[rule.operation_key] ?? fallback.OTHER;
}
function confidenceScore(level: unknown): number {
  switch (String(level ?? "").toUpperCase()) {
    case "HIGH":
      return 0.90;
    case "MEDIUM":
      return 0.70;
    case "LOW":
      return 0.50;
    default:
      return 0.50;
  }
}

function nextPreSummerDate(events: any[]): string {
  const now = new Date();
  let year = now.getUTCFullYear();
  const targetFor = (value: number) => new Date(Date.UTC(value, 4, 15, 12));
  if (targetFor(year).getTime() <= Date.now()) year += 1;
  const lastClimate = events.find((event: any) => operationMatches("CLIMATE", event));
  if (lastClimate?.occurred_at) {
    const last = Date.parse(`${String(lastClimate.occurred_at).slice(0, 10)}T12:00:00Z`);
    while (Number.isFinite(last) && targetFor(year).getTime() - last < 300 * 86400000) year += 1;
  }
  return `${year}-05-15`;
}
function buildSeasonalClimateSchedule(vehicleId: string, userId: string, events: any[]): any {
  const dueDate = nextPreSummerDate(events);
  const days = daysUntil(dueDate);
  return {
    vehicle_id: vehicleId,
    user_id: userId,
    title: "Contrôle climatisation avant l’été",
    schedule_type: "MAINTENANCE",
    due_date: dueDate,
    due_mileage: null,
    interval_months: 12,
    interval_km: null,
    status: "ACTIVE",
    priority: days != null && days <= 75 ? "MEDIUM" : "LOW",
    source_type: 'AUTOCLAIR_RULE',
    reason: "Pourquoi ? Vérifier son fonctionnement avant les fortes chaleurs aide à éviter de découvrir une climatisation inefficace juste avant les vacances. · Conseil AutoClair : contrôle de fonctionnement, pas recharge systématique.",
    source_key: "SEASONAL:CLIMATE",
    source_url: null,
    source_label: "Conseil AutoClair",
    confidence: confidenceScore("HIGH"),
    source_quality: "AUTOCLAIR_GUIDANCE",
    calculation_basis: "SEASONAL_ADVICE",
    manufacturer_plan_id: null,
  };
}
function theoreticalMileage(rule: Rule, currentMileage: number | null): number | null {
  if (currentMileage == null) return rule.first_due_km ?? rule.interval_km;
  const interval = rule.interval_km;
  let due = rule.first_due_km ?? interval;
  if (due == null) return null;
  if (interval == null || interval <= 0) return due > currentMileage ? due : null;
  while (due <= currentMileage) due += interval;
  return due;
}

function theoreticalDate(rule: Rule, firstRegistration: string | null): string | null {
  if (!firstRegistration) return null;
  const interval = rule.interval_months;
  const first = rule.first_due_months ?? interval;
  if (first == null || first <= 0) return null;
  let due = addMonths(firstRegistration, first);
  if (interval == null || interval <= 0) {
    return Date.parse(`${due}T12:00:00Z`) > Date.now() ? due : null;
  }
  while (Date.parse(`${due}T12:00:00Z`) <= Date.now()) due = addMonths(due, interval);
  return due;
}

function priorityFor(
  basis: string,
  dueDate: string | null,
  dueMileage: number | null,
  currentMileage: number | null,
): string {
  const days = daysUntil(dueDate);
  const km = dueMileage != null && currentMileage != null ? dueMileage - currentMileage : null;
  if (basis === "HISTORY_CONFIRMED") {
    if ((days != null && days < 0) || (km != null && km <= 0)) return "HIGH";
    if ((days != null && days <= 60) || (km != null && km <= 2000)) return "MEDIUM";
    return "LOW";
  }
  if ((days != null && days <= 90) || (km != null && km <= 3000)) return "MEDIUM";
  return "LOW";
}

function selectSource(rule: Rule, sources: SourceRef[]): SourceRef | null {
  const wanted = rule.source_domain.toLowerCase().replace(/^www\./, "");
  return sources.find((source) => source.domain === wanted || source.domain.endsWith(`.${wanted}`))
    ?? sources[0]
    ?? null;
}

function isBundledRoutineComponent(rule: Rule, rules: Rule[]): boolean {
  if (!['ENGINE_OIL', 'OIL_FILTER'].includes(rule.operation_key)) return false;
  return rules.some((candidate) => {
    if (candidate.operation_key !== 'SERVICE') return false;
    const pairs = [
      [rule.interval_km, candidate.interval_km],
      [rule.interval_months, candidate.interval_months],
      [rule.first_due_km, candidate.first_due_km],
      [rule.first_due_months, candidate.first_due_months],
    ];
    let matched = false;
    for (const [left, right] of pairs) {
      if (left == null || right == null) continue;
      if (left !== right) return false;
      matched = true;
    }
    return matched;
  });
}
async function researchPlan(
  vehicle: any,
  technicalIdentity: unknown,
  maintenanceHistory: any[],
  domains: string[],
  openaiKey: string,
): Promise<{ plan: any; sources: SourceRef[] }> {
  const prompt = [
    "You are researching an automotive manufacturer maintenance schedule for AutoClair in France.",
    "You MUST use web search and ONLY the official manufacturer domains allowed by the tool.",
    "Never use forums, dealer blogs, aggregators, generic automotive knowledge, or inferred intervals.",
    "Use the exact make, model, year, fuel/powertrain and privacy-minimized technical identity to determine whether the official information truly applies to this vehicle variant.",
    "The maintenance_history below is a privacy-minimized technical summary of completed work on THIS vehicle. It is context for relevance only, never a source for manufacturer intervals.",
    "Return only standalone service or replacement operations for which the official source supports an interval in kilometres/months or a first due threshold.",
    "Routine inspection-only checks such as lighting, fluid levels, tyre pressure, visual tyre/brake checks, suspension/liaisons au sol and wipers MUST NOT become independent maintenance rules when they are normally checked during a service.",
    "When the official schedule treats engine oil, oil filter and routine inspections as one service at the same interval, prefer one SERVICE rule instead of several duplicate rules.",
    "Do not return a climate/air-conditioning rule. AutoClair handles its seasonal comfort check separately and never assumes an annual refrigerant recharge.",
    "If the official material is not precise enough for this model/year/powertrain, return status UNAVAILABLE rather than guessing.",
    "OFFICIAL_EXACT means the official source supports the exact model/version/engine information supplied.",
    "OFFICIAL_GENERAL means the source is official but only supports the model family or a broader maintenance policy that still clearly applies.",
    "Do not calculate the user's personal next due date. AutoClair will calculate dates and mileage deterministically from confirmed history, current mileage and first registration.",
    "For every returned rule, write benefit as one short French sentence explaining the practical advantage of doing that maintenance, without alarming language or guarantees.",
    "Do not output VIN, registration plate, owner information, personal data, prices, recalls or any raw document text.",
    "Vehicle and history (privacy-minimized):",
    JSON.stringify({
      make: vehicle.make,
      model: vehicle.model,
      vehicle_year: vehicle.vehicle_year,
      fuel_type: vehicle.fuel_type,
      technical_identity: technicalIdentity,
      maintenance_history: maintenanceHistory,
    }),
  ].join("\n");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openaiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      store: false,
      reasoning: { effort: "low" },
      tools: [{
        type: "web_search",
        filters: { allowed_domains: domains },
      }],
      tool_choice: "required",
      include: ["web_search_call.action.sources"],
      input: prompt,
      text: {
        format: {
          type: "json_schema",
          name: "autoclair_manufacturer_maintenance_plan_v2",
          strict: true,
          schema,
        },
      },
      max_output_tokens: 30000,
    }),
  });
  const raw = await response.text();
  if (!response.ok) throw new Error(`OPENAI_${response.status}:${raw.slice(0, 600)}`);
  const decoded = JSON.parse(raw);
  if (decoded?.status === "incomplete") {
    const reason = String(decoded?.incomplete_details?.reason ?? "unknown");
    throw new Error(`OPENAI_INCOMPLETE:${reason}`);
  }
  const text = outputText(decoded);
  if (!text) throw new Error("OPENAI_EMPTY_OUTPUT");
  const plan = JSON.parse(text);
  const sources = collectSources(decoded, domains);
  return { plan, sources };
}
function classifyMaintenanceFailure(error: unknown): {
  code: string;
  retryable: boolean;
} {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.startsWith("OPENAI_INCOMPLETE:") || message === "OPENAI_EMPTY_OUTPUT") {
    return { code: "AI_RESPONSE_INCOMPLETE", retryable: true };
  }
  if (message.startsWith("OPENAI_401") || message.startsWith("OPENAI_403")) {
    return { code: "AI_CONFIGURATION_ERROR", retryable: false };
  }
  if (message.startsWith("OPENAI_429") || /^OPENAI_5\d\d/.test(message)) {
    return { code: "AI_TEMPORARILY_UNAVAILABLE", retryable: true };
  }
  if (message.startsWith("OPENAI_")) return { code: "AI_REQUEST_FAILED", retryable: true };
  if (message.includes('invalid input syntax for type numeric')) {
    return { code: "MAINTENANCE_DATA_ERROR", retryable: false };
  }
  return { code: "MAINTENANCE_SERVICE_ERROR", retryable: true };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { success: false, error: "METHOD_NOT_ALLOWED" });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRole || !openaiKey) {
      return json(503, { success: false, error: "BACKEND_NOT_CONFIGURED" });
    }

    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) {
      return json(401, { success: false, error: "AUTH_REQUIRED" });
    }
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const admin = createClient(supabaseUrl, serviceRole, {
      auth: { persistSession: false },
    });
    const token = authorization.slice("Bearer ".length);
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    const user = authData?.user;
    if (authError || !user) return json(401, { success: false, error: "AUTH_REQUIRED" });

    const body = await req.json().catch(() => ({}));
    const vehicleId = String(body?.vehicle_id ?? "").trim();
    const forceRefresh = body?.force_refresh === true;
    if (!vehicleId) return json(400, { success: false, error: "VEHICLE_REQUIRED" });

    const { data: vehicle, error: vehicleError } = await admin
      .from("vehicles")
      .select("id,user_id,make,model,vehicle_year,fuel_type,mileage,first_registration_date")
      .eq("id", vehicleId)
      .maybeSingle();
    if (vehicleError || !vehicle || vehicle.user_id !== user.id) {
      return json(404, { success: false, error: "VEHICLE_NOT_FOUND" });
    }

    const { data: events, error: eventsError } = await admin
      .from("vehicle_events")
      .select("event_type,title,occurred_at,mileage,status")
      .eq("vehicle_id", vehicleId)
      .eq("status", "COMPLETED")
      .order("occurred_at", { ascending: false })
      .limit(250);
    if (eventsError) throw eventsError;
    const completedEvents = events ?? [];
    const maintenanceHistory = buildMaintenanceHistory(completedEvents);
    const historyFingerprint = await sha256(maintenanceHistory);
    const seasonalSchedule = buildSeasonalClimateSchedule(vehicleId, user.id, completedEvents);

    const domains = officialDomains[normalizedMake(vehicle.make)];
    if (!domains?.length) {
      const { error: seasonalError } = await admin
        .from("vehicle_maintenance_schedules")
        .upsert([seasonalSchedule], { onConflict: "vehicle_id,source_key" });
      if (seasonalError) throw seasonalError;
      const { data: stale } = await admin
        .from("vehicle_maintenance_schedules")
        .select("id")
        .eq("vehicle_id", vehicleId)
        .like("source_key", "MFR:%");
      const staleIds = (stale ?? []).map((row: any) => row.id);
      if (staleIds.length) {
        const { error } = await admin.from("vehicle_maintenance_schedules").delete().in("id", staleIds);
        if (error) throw error;
      }
      await userClient.rpc("recalculate_vehicle_reminders", { p_vehicle_id: vehicleId });
      return json(200, {
        success: true,
        status: "UNAVAILABLE",
        reason: "UNSUPPORTED_MAKE",
        manufacturer_schedules: 0,
        seasonal_schedule: true,
        history_entries: maintenanceHistory.length,
      });
    }

    const { data: profile } = await admin
      .from("vehicle_identification_profiles")
      .select("identity,technical,aftersales,retrieved_at")
      .eq("vehicle_id", vehicleId)
      .order("retrieved_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    const technicalIdentity = sanitizeProfile({
      identity: profile?.identity ?? {},
      technical: profile?.technical ?? {},
      aftersales: profile?.aftersales ?? {},
    });
    const signatureInput = {
      make: normalizedMake(vehicle.make),
      model: String(vehicle.model ?? "").trim().toLowerCase(),
      year: vehicle.vehicle_year ?? null,
      fuel: String(vehicle.fuel_type ?? "").trim().toLowerCase(),
      technical_identity: technicalIdentity,
    };
    const vehicleSignature = await sha256(signatureInput);
    const researchSignature = await sha256({
      vehicle_signature: vehicleSignature,
      history_fingerprint: historyFingerprint,
    });

    let cache: any = null;
    if (!forceRefresh) {
      const { data } = await admin
        .from("manufacturer_maintenance_plans")
        .select("*")
        .eq("vehicle_signature", researchSignature)
        .gt("expires_at", new Date().toISOString())
        .maybeSingle();
      if (data?.plan_json?.history_fingerprint === historyFingerprint) cache = data;
    }

    let plan: any;
    let sources: SourceRef[];
    let planId: string | null = cache?.id ?? null;
    if (cache) {
      plan = cache.plan_json;
      sources = Array.isArray(cache.sources) ? cache.sources : [];
    } else {
      const researched = await researchPlan(
        vehicle,
        technicalIdentity,
        maintenanceHistory,
        domains,
        openaiKey,
      );
      plan = {
        ...researched.plan,
        history_fingerprint: historyFingerprint,
      };
      sources = researched.sources;
      if (plan?.status === "READY" && (!Array.isArray(plan.rules) || !plan.rules.length || !sources.length)) {
        plan = {
          status: "UNAVAILABLE",
          source_quality: "UNAVAILABLE",
          vehicle_match_summary: "",
          summary: "Source constructeur officielle insuffisante.",
          rules: [],
          history_fingerprint: historyFingerprint,
        };
      }
      const unavailable = plan?.status !== "READY";
      const expiresAt = new Date(
        Date.now() + (unavailable ? CACHE_DAYS_UNAVAILABLE : CACHE_DAYS_READY) * 86400000,
      ).toISOString();
      const { data: cached, error: cacheError } = await admin
        .from("manufacturer_maintenance_plans")
        .upsert({
          vehicle_signature: researchSignature,
          make: vehicle.make,
          model: vehicle.model,
          vehicle_year: vehicle.vehicle_year,
          fuel_type: vehicle.fuel_type,
          identity: technicalIdentity ?? {},
          source_quality: unavailable ? "UNAVAILABLE" : plan.source_quality,
          plan_json: plan,
          sources,
          model_id: OPENAI_MODEL,
          researched_at: new Date().toISOString(),
          expires_at: expiresAt,
          updated_at: new Date().toISOString(),
        }, { onConflict: "vehicle_signature" })
        .select("id")
        .single();
      if (cacheError) throw cacheError;
      planId = cached.id;
    }

    const schedules: any[] = [seasonalSchedule];
    const keptKeys = new Set<string>();
    let manufacturerCount = 0;
    const researchedRules: Rule[] = Array.isArray(plan?.rules) ? plan.rules : [];
    if (plan?.status === "READY") {
      for (const rule of researchedRules) {
        if (!rule?.rule_key || !rule?.title) continue;
        if (isRoutineCheckOnlyTitle(rule.title)) continue;
        if (isBundledRoutineComponent(rule, researchedRules)) continue;
        if (rule.interval_km == null && rule.interval_months == null &&
            rule.first_due_km == null && rule.first_due_months == null) continue;

        const matching = completedEvents.find((event: any) => operationMatches(rule.operation_key, event));
        let dueDate: string | null = null;
        let dueMileage: number | null = null;
        let basis = "THEORETICAL_CYCLE";
        if (matching) {
          basis = "HISTORY_CONFIRMED";
          if (rule.interval_months && matching.occurred_at) {
            dueDate = addMonths(String(matching.occurred_at).slice(0, 10), rule.interval_months);
          }
          if (rule.interval_km && matching.mileage != null) {
            dueMileage = Number(matching.mileage) + rule.interval_km;
          }
        } else {
          dueDate = theoreticalDate(rule, vehicle.first_registration_date ?? null);
          dueMileage = theoreticalMileage(
            rule,
            vehicle.mileage == null ? null : Number(vehicle.mileage),
          );
        }
        if (dueDate == null && dueMileage == null) continue;
        const source = selectSource(rule, sources);
        if (!source) continue;
        const key = `MFR:${vehicleSignature.slice(0, 16)}:${rule.rule_key}`.slice(0, 180);
        keptKeys.add(key);
        const priority = priorityFor(
          basis,
          dueDate,
          dueMileage,
          vehicle.mileage == null ? null : Number(vehicle.mileage),
        );
        const benefit = benefitFor(rule);
        const calculation = basis === "HISTORY_CONFIRMED"
          ? "calculée depuis une intervention connue du carnet"
          : "cycle constructeur théorique à confirmer si l’historique est incomplet";
        const reason = `Pourquoi ? ${benefit} · Préconisation constructeur sourcée · ${calculation}. ${rule.applicability_notes}`.trim();
        schedules.push({
          vehicle_id: vehicleId,
          user_id: user.id,
          title: rule.title,
          schedule_type: "MAINTENANCE",
          due_date: dueDate,
          due_mileage: dueMileage,
          interval_months: rule.interval_months,
          interval_km: rule.interval_km,
          status: "ACTIVE",
          priority,
          source_type: "AUTOCLAIR_RULE",
          reason,
          source_key: key,
          source_url: source.url,
          source_label: source.title,
          confidence: confidenceScore(rule.confidence),
          source_quality: plan.source_quality,
          calculation_basis: basis,
          manufacturer_plan_id: planId,
        });
        manufacturerCount += 1;
      }
    }

    const { error: upsertError } = await admin
      .from("vehicle_maintenance_schedules")
      .upsert(schedules, { onConflict: "vehicle_id,source_key" });
    if (upsertError) throw upsertError;

    const { data: previous } = await admin
      .from("vehicle_maintenance_schedules")
      .select("id,source_key")
      .eq("vehicle_id", vehicleId)
      .like("source_key", "MFR:%");
    const staleIds = (previous ?? [])
      .filter((row: any) => row.source_key && !keptKeys.has(row.source_key))
      .map((row: any) => row.id);
    if (staleIds.length) {
      const { error } = await admin.from("vehicle_maintenance_schedules").delete().in("id", staleIds);
      if (error) throw error;
    }

    const { error: reminderError } = await userClient.rpc(
      "recalculate_vehicle_reminders",
      { p_vehicle_id: vehicleId },
    );
    if (reminderError) throw reminderError;
    return json(200, {
      success: true,
      status: manufacturerCount > 0 ? "READY" : "UNAVAILABLE",
      cached: !!cache,
      source_quality: manufacturerCount > 0 ? plan.source_quality : "UNAVAILABLE",
      manufacturer_schedules: manufacturerCount,
      seasonal_schedule: true,
      history_entries: maintenanceHistory.length,
    });
  } catch (error) {
    const classified = classifyMaintenanceFailure(error);
    const internalMessage = error instanceof Error
      ? error.message.slice(0, 1200)
      : String(error).slice(0, 1200);
    console.error("refresh-vehicle-maintenance-plan", {
      code: classified.code,
      message: internalMessage,
    });
    return json(500, {
      success: false,
      error: classified.code,
      retryable: classified.retryable,
    });
  }
});
