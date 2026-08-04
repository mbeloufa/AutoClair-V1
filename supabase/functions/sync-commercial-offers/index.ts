import { createClient } from "npm:@supabase/supabase-js@2";
import {
  extractOfferLinks,
  extractOffers,
  normalizeText,
  type ExtractionSource,
  type ExtractedOffer,
  type KnownVehicle,
} from "./extractor.ts";

type JsonMap = Record<string, unknown>;

type SourceRow = {
  id: string;
  source_key: string;
  source_name: string;
  source_url: string;
  allowed_hostnames: string[];
  status: string;
  content_hash: string | null;
  failure_count: number;
  metadata: JsonMap;
  search_enabled: boolean;
  search_priority: number;
  check_frequency_hours: number;
  monitoring_mode: ExtractionSource["monitoringMode"];
  publication_policy: ExtractionSource["publicationPolicy"];
  source_purpose: ExtractionSource["sourcePurpose"];
  endpoint_type: ExtractionSource["endpointType"];
  trust_tier: ExtractionSource["trustTier"];
  canonical_brand_code: string;
  auto_publish_threshold: number;
  crawl_depth: number;
  max_pages_per_cycle: number;
};

type CrawlTargetRow = {
  id: string;
  source_id: string;
  target_url: string;
  url_hash: string;
  target_kind: "ROOT" | "DISCOVERED";
  depth: number;
  status: string;
  priority: number;
  check_frequency_hours: number;
  next_check_at: string | null;
  failure_count: number;
  content_hash: string | null;
};

type FetchResult = {
  html: string;
  normalizedText: string;
  finalUrl: URL;
  status: number;
  contentHash: string;
  robotsStatus: "ALLOWED" | "DISALLOWED" | "UNAVAILABLE";
};

type TaskOutcome = {
  sourceKey: string;
  targetUrl: string;
  success: boolean;
  published: number;
  updated: number;
  candidates: number;
  discoveredUrls: number;
  verifiedManualOffers: number;
  reviewedManualOffers: number;
  highConfidence: number;
  errorCode?: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";

function readAdminKey(): string {
  const modern = Deno.env.get("SUPABASE_SECRET_KEYS");

  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, unknown>;
      const preferred = parsed.default;

      if (typeof preferred === "string" && preferred.trim()) {
        return preferred.trim();
      }

      for (const value of Object.values(parsed)) {
        if (typeof value === "string" && value.trim()) {
          return value.trim();
        }
      }
    } catch {
      // The legacy service-role variable remains the fallback.
    }
  }

  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
}

const SERVICE_ROLE_KEY = readAdminKey();

const MAX_HTML_BYTES = 2_000_000;
const FETCH_TIMEOUT_MS = 12_000;
const MAX_BATCH_SIZE = 6;
const USER_AGENT =
  "AutoClairOffersBot/3.0 (+deterministic-offer-extraction; France)";
const BOT_NAME = "AutoClairOffersBot";

const responseHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "content-type, x-sync-secret, authorization, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  });
}

function adminClient(): any {
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    throw new Error("SUPABASE_ADMIN_CONFIGURATION_MISSING");
  }

  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: {
      headers: {
        "X-Client-Info": "autoclair-commercial-offers-sync/3.0",
      },
    },
  });
}

function isRecord(value: unknown): value is JsonMap {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function safeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  try {
    return JSON.stringify(error);
  } catch {
    return "UNKNOWN_ERROR";
  }
}

function integerInRange(
  value: unknown,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const parsed = typeof value === "number"
    ? value
    : Number.parseInt(String(value ?? ""), 10);

  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(minimum, Math.min(maximum, Math.trunc(parsed)));
}

function asBoolean(value: unknown): boolean {
  if (value === true || value === 1 || value === "1") return true;
  if (typeof value === "string") {
    return ["true", "yes", "y", "oui"].includes(value.toLowerCase());
  }
  return false;
}

async function readJsonBody(request: Request): Promise<JsonMap> {
  const text = await request.text();
  if (!text.trim()) return {};

  const value = JSON.parse(text);
  if (!isRecord(value)) {
    throw new Error("REQUEST_BODY_INVALID");
  }
  return value;
}

async function sha256Hex(value: unknown): Promise<string> {
  const serialized = typeof value === "string"
    ? value
    : JSON.stringify(value);
  const bytes = new TextEncoder().encode(serialized);
  const digest = await crypto.subtle.digest("SHA-256", bytes);

  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function normalizedHostname(value: string): string {
  return value.trim().toLowerCase().replace(/\.$/, "");
}

function hostnameAllowed(
  hostname: string,
  allowedHostnames: string[],
): boolean {
  const normalized = normalizedHostname(hostname);

  return allowedHostnames.some(
    (allowed) => normalized === normalizedHostname(allowed),
  );
}

function validatedHttpsUrl(
  raw: string,
  allowedHostnames: string[],
): URL {
  const url = new URL(raw);

  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    !hostnameAllowed(url.hostname, allowedHostnames)
  ) {
    throw new Error("SOURCE_URL_NOT_ALLOWED");
  }

  return url;
}

async function fetchWithTimeout(
  url: URL,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort(),
    FETCH_TIMEOUT_MS,
  );

  try {
    return await fetch(url, {
      ...init,
      signal: controller.signal,
      redirect: "follow",
    });
  } finally {
    clearTimeout(timeout);
  }
}

type RobotsRule = {
  path: string;
  allow: boolean;
};

function parseRobotsRules(
  robotsText: string,
  userAgent: string,
): RobotsRule[] {
  const groups: Array<{
    agents: string[];
    rules: RobotsRule[];
  }> = [];

  let currentAgents: string[] = [];
  let currentRules: RobotsRule[] = [];

  const flush = () => {
    if (currentAgents.length > 0) {
      groups.push({
        agents: currentAgents,
        rules: currentRules,
      });
    }
    currentAgents = [];
    currentRules = [];
  };

  for (const rawLine of robotsText.split(/\r?\n/)) {
    const line = rawLine.replace(/#.*$/, "").trim();
    if (!line) continue;

    const separator = line.indexOf(":");
    if (separator < 0) continue;

    const field = line.slice(0, separator).trim().toLowerCase();
    const value = line.slice(separator + 1).trim();

    if (field === "user-agent") {
      if (currentRules.length > 0) flush();
      currentAgents.push(value.toLowerCase());
      continue;
    }

    if (
      (field === "allow" || field === "disallow") &&
      currentAgents.length > 0
    ) {
      if (!value && field === "disallow") continue;
      currentRules.push({
        path: value,
        allow: field === "allow",
      });
    }
  }

  flush();

  const requested = userAgent.toLowerCase();
  const specific = groups.filter((group) =>
    group.agents.some((agent) =>
      requested.includes(agent) || agent.includes(requested)
    )
  );

  if (specific.length > 0) {
    return specific.flatMap((group) => group.rules);
  }

  return groups
    .filter((group) => group.agents.includes("*"))
    .flatMap((group) => group.rules);
}

function robotsAllows(
  rules: RobotsRule[],
  url: URL,
): boolean {
  const candidate = `${url.pathname}${url.search}`;
  const matches = rules
    .filter((rule) => rule.path && candidate.startsWith(rule.path))
    .sort((a, b) => b.path.length - a.path.length);

  return matches.length === 0 ? true : matches[0].allow;
}

const robotsCache = new Map<
  string,
  "ALLOWED" | "DISALLOWED" | "UNAVAILABLE"
>();

async function checkRobots(
  sourceUrl: URL,
  allowedHostnames: string[],
): Promise<"ALLOWED" | "DISALLOWED" | "UNAVAILABLE"> {
  const cacheKey = sourceUrl.origin;
  const cached = robotsCache.get(cacheKey);
  if (cached) return cached;

  const robotsUrl = new URL("/robots.txt", sourceUrl.origin);

  try {
    const response = await fetchWithTimeout(robotsUrl, {
      method: "GET",
      headers: {
        Accept: "text/plain,*/*;q=0.1",
        "User-Agent": USER_AGENT,
      },
    });

    if (response.status === 404) {
      robotsCache.set(cacheKey, "ALLOWED");
      return "ALLOWED";
    }

    if (!response.ok) {
      robotsCache.set(cacheKey, "UNAVAILABLE");
      return "UNAVAILABLE";
    }

    const finalUrl = new URL(response.url || robotsUrl.toString());

    if (!hostnameAllowed(finalUrl.hostname, allowedHostnames)) {
      robotsCache.set(cacheKey, "DISALLOWED");
      return "DISALLOWED";
    }

    const robotsText = await response.text();
    const rules = parseRobotsRules(robotsText, BOT_NAME);
    const status = robotsAllows(rules, sourceUrl)
      ? "ALLOWED"
      : "DISALLOWED";

    robotsCache.set(cacheKey, status);
    return status;
  } catch {
    robotsCache.set(cacheKey, "UNAVAILABLE");
    return "UNAVAILABLE";
  }
}

async function fetchPage(
  targetUrl: string,
  allowedHostnames: string[],
): Promise<FetchResult> {
  const url = validatedHttpsUrl(targetUrl, allowedHostnames);
  const robotsStatus = await checkRobots(url, allowedHostnames);

  if (robotsStatus === "DISALLOWED") {
    throw new Error("ROBOTS_DISALLOWED");
  }

  const response = await fetchWithTimeout(url, {
    method: "GET",
    headers: {
      Accept: "text/html,application/xhtml+xml",
      "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.4",
      "User-Agent": USER_AGENT,
    },
  });

  const finalUrl = new URL(response.url || url.toString());

  if (!hostnameAllowed(finalUrl.hostname, allowedHostnames)) {
    throw new Error("UNAPPROVED_REDIRECT_HOST");
  }

  if (!response.ok) {
    throw new Error(`SOURCE_HTTP_${response.status}`);
  }

  const contentType =
    response.headers.get("content-type")?.toLowerCase() ?? "";

  if (
    !contentType.includes("text/html") &&
    !contentType.includes("application/xhtml+xml")
  ) {
    throw new Error("SOURCE_CONTENT_TYPE_INVALID");
  }

  const contentLength = Number(
    response.headers.get("content-length") ?? "0",
  );

  if (
    Number.isFinite(contentLength) &&
    contentLength > MAX_HTML_BYTES
  ) {
    throw new Error("SOURCE_CONTENT_TOO_LARGE");
  }

  const html = await response.text();
  if (new TextEncoder().encode(html).byteLength > MAX_HTML_BYTES) {
    throw new Error("SOURCE_CONTENT_TOO_LARGE");
  }

  const normalizedText = normalizeText(html.replace(/<[^>]+>/g, " "));
  if (normalizedText.length < 200) {
    throw new Error("SOURCE_CONTENT_TOO_SHORT");
  }

  return {
    html,
    normalizedText,
    finalUrl,
    status: response.status,
    contentHash: await sha256Hex(normalizedText),
    robotsStatus,
  };
}

function sourceFromRow(row: JsonMap): SourceRow {
  return {
    id: String(row.id ?? ""),
    source_key: String(row.source_key ?? ""),
    source_name: String(row.source_name ?? ""),
    source_url: String(row.source_url ?? ""),
    allowed_hostnames: Array.isArray(row.allowed_hostnames)
      ? row.allowed_hostnames.map(String)
      : [],
    status: String(row.status ?? "PAUSED"),
    content_hash: typeof row.content_hash === "string"
      ? row.content_hash
      : null,
    failure_count: integerInRange(row.failure_count, 0, 0, 10_000),
    metadata: isRecord(row.metadata) ? row.metadata : {},
    search_enabled: row.search_enabled === true,
    search_priority: integerInRange(row.search_priority, 50, 1, 100),
    check_frequency_hours: integerInRange(
      row.check_frequency_hours,
      72,
      6,
      720,
    ),
    monitoring_mode: String(
      row.monitoring_mode ?? "HTML_DISCOVERY",
    ) as SourceRow["monitoring_mode"],
    publication_policy: String(
      row.publication_policy ?? "QUARANTINE_ONLY",
    ) as SourceRow["publication_policy"],
    source_purpose: String(
      row.source_purpose ?? "OTHER",
    ) as SourceRow["source_purpose"],
    endpoint_type: String(
      row.endpoint_type ?? "HOME_OR_CATALOG",
    ) as SourceRow["endpoint_type"],
    trust_tier: String(
      row.trust_tier ?? "PROFESSIONAL",
    ) as SourceRow["trust_tier"],
    canonical_brand_code: String(
      row.canonical_brand_code ?? "*",
    ),
    auto_publish_threshold: integerInRange(
      row.auto_publish_threshold,
      86,
      70,
      100,
    ),
    crawl_depth: integerInRange(row.crawl_depth, 1, 0, 2),
    max_pages_per_cycle: integerInRange(
      row.max_pages_per_cycle,
      4,
      1,
      10,
    ),
  };
}

function taskFromRow(row: JsonMap): CrawlTargetRow {
  return {
    id: String(row.id ?? ""),
    source_id: String(row.source_id ?? ""),
    target_url: String(row.target_url ?? ""),
    url_hash: String(row.url_hash ?? ""),
    target_kind: String(
      row.target_kind ?? "ROOT",
    ) as CrawlTargetRow["target_kind"],
    depth: integerInRange(row.depth, 0, 0, 2),
    status: String(row.status ?? "ACTIVE"),
    priority: integerInRange(row.priority, 50, 1, 100),
    check_frequency_hours: integerInRange(
      row.check_frequency_hours,
      72,
      6,
      720,
    ),
    next_check_at: typeof row.next_check_at === "string"
      ? row.next_check_at
      : null,
    failure_count: integerInRange(row.failure_count, 0, 0, 10_000),
    content_hash: typeof row.content_hash === "string"
      ? row.content_hash
      : null,
  };
}

async function loadDueTasks(
  client: any,
  batchSize: number,
): Promise<Array<{ task: CrawlTargetRow; source: SourceRow }>> {
  const now = new Date().toISOString();

  const { data: rawTasks, error: taskError } = await client
    .from("commercial_offer_crawl_targets")
    .select("*")
    .in("status", ["ACTIVE", "ERROR"])
    .or(`next_check_at.is.null,next_check_at.lte.${now}`)
    .order("priority", { ascending: true })
    .order("next_check_at", { ascending: true, nullsFirst: true })
    .limit(80);

  if (taskError) {
    throw new Error(`CRAWL_TARGETS_READ_FAILED:${taskError.message}`);
  }

  const taskRows: unknown[] = Array.isArray(rawTasks)
    ? rawTasks
    : [];

  const tasks: CrawlTargetRow[] = taskRows
    .filter(isRecord)
    .map(taskFromRow)
    .filter(
      (task: CrawlTargetRow) =>
        Boolean(task.id && task.source_id && task.target_url),
    );

  if (tasks.length === 0) return [];

  const sourceIds = Array.from(
    new Set(tasks.map((task: CrawlTargetRow) => task.source_id)),
  );

  const { data: rawSources, error: sourceError } = await client
    .from("commercial_offer_sources")
    .select(
      "id,source_key,source_name,source_url,allowed_hostnames,status," +
        "content_hash,failure_count,metadata,search_enabled," +
        "search_priority,check_frequency_hours,monitoring_mode," +
        "publication_policy,source_purpose,endpoint_type,trust_tier," +
        "canonical_brand_code,auto_publish_threshold,crawl_depth," +
        "max_pages_per_cycle",
    )
    .in("id", sourceIds);

  if (sourceError) {
    throw new Error(`SOURCES_READ_FAILED:${sourceError.message}`);
  }

  const sources = new Map<string, SourceRow>();

  const sourceRows: unknown[] = Array.isArray(rawSources)
    ? rawSources
    : [];

  for (const rawSource of sourceRows) {
    if (!isRecord(rawSource)) continue;
    const source = sourceFromRow(rawSource);
    if (source.id) sources.set(source.id, source);
  }

  return tasks
    .map((task: CrawlTargetRow) => ({
      task,
      source: sources.get(task.source_id),
    }))
    .filter(
      (
        value: {
          task: CrawlTargetRow;
          source: SourceRow | undefined;
        },
      ): value is { task: CrawlTargetRow; source: SourceRow } =>
        Boolean(value.source?.search_enabled),
    )
    .sort((
      a: { task: CrawlTargetRow; source: SourceRow },
      b: { task: CrawlTargetRow; source: SourceRow },
    ) => {
      const rootOrder =
        Number(a.task.target_kind !== "ROOT") -
        Number(b.task.target_kind !== "ROOT");
      return rootOrder ||
        a.task.priority - b.task.priority ||
        a.task.target_url.localeCompare(b.task.target_url);
    })
    .slice(0, batchSize);
}

async function loadKnownVehicles(client: any): Promise<KnownVehicle[]> {
  const { data, error } = await client
    .from("vehicles")
    .select("make,model")
    .not("make", "is", null)
    .not("model", "is", null)
    .limit(2_000);

  if (error) {
    throw new Error(`VEHICLE_MODELS_READ_FAILED:${error.message}`);
  }

  const seen = new Set<string>();
  const vehicles: KnownVehicle[] = [];

  for (const row of data ?? []) {
    if (!isRecord(row)) continue;

    const make = String(row.make ?? "").trim();
    const model = String(row.model ?? "").trim();
    if (!make || !model) continue;

    const key = `${normalizeText(make)}::${normalizeText(model)}`;
    if (seen.has(key)) continue;
    seen.add(key);

    vehicles.push({
      brand: normalizeText(make),
      model,
    });
  }

  return vehicles;
}

function extractionSource(source: SourceRow): ExtractionSource {
  return {
    sourceKey: source.source_key,
    sourceName: source.source_name,
    sourceUrl: source.source_url,
    canonicalBrandCode: source.canonical_brand_code,
    sourcePurpose: source.source_purpose,
    endpointType: source.endpoint_type,
    trustTier: source.trust_tier,
    monitoringMode: source.monitoring_mode,
    publicationPolicy: source.publication_policy,
    autoPublishThreshold: source.auto_publish_threshold,
  };
}

function nextCheckIso(
  hours: number,
  failureCount = 0,
): string {
  const backoff = failureCount <= 0
    ? hours
    : Math.min(168, Math.max(6, hours * Math.pow(2, failureCount - 1)));

  return new Date(
    Date.now() + backoff * 60 * 60 * 1_000,
  ).toISOString();
}

function safeOfferKey(sourceKey: string, fingerprint: string): string {
  const sourcePart = sourceKey
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 34);

  return `auto_${sourcePart}_${fingerprint.slice(0, 20)}`;
}

async function publishOffer(
  client: any,
  source: SourceRow,
  offer: ExtractedOffer,
  pageUrl: string,
): Promise<"PUBLISHED" | "UPDATED"> {
  const now = new Date().toISOString();

  const { data: existing, error: existingError } = await client
    .from("commercial_offers")
    .select("id")
    .eq("source_id", source.id)
    .eq("source_fingerprint", offer.fingerprint)
    .maybeSingle();

  if (existingError) {
    throw new Error(
      `AUTO_OFFER_LOOKUP_FAILED:${existingError.message}`,
    );
  }

  const payload = {
    source_id: source.id,
    offer_key: safeOfferKey(source.source_key, offer.fingerprint),
    title: offer.title,
    summary: offer.summary,
    category: offer.category,
    benefit_kind: offer.benefitKind,
    benefit_label: offer.benefitLabel,
    benefit_value: offer.benefitValue,
    price_amount: offer.priceAmount,
    original_price_amount: offer.originalPriceAmount,
    currency: offer.currency,
    starts_at: offer.startsAt,
    ends_at: offer.endsAt,
    status: offer.endsAt &&
        new Date(`${offer.endsAt}T23:59:59Z`).getTime() < Date.now()
      ? "EXPIRED"
      : "ACTIVE",
    official_url: offer.officialUrl,
    brands: offer.brands,
    model_patterns: offer.modelPatterns,
    excluded_model_patterns: offer.excludedModelPatterns,
    fuel_types: offer.fuelTypes,
    excluded_fuel_types: offer.excludedFuelTypes,
    year_min: offer.yearMin,
    year_max: offer.yearMax,
    age_min: offer.ageMin,
    age_max: offer.ageMax,
    mileage_min: offer.mileageMin,
    mileage_max: offer.mileageMax,
    schedule_keywords: offer.scheduleKeywords,
    conditions_summary: offer.conditionsSummary,
    eligibility_notes: offer.eligibilityNotes,
    requires_existing_contract: offer.requiresExistingContract,
    requires_network_participation:
      offer.requiresNetworkParticipation,
    requires_manual_eligibility: offer.requiresManualEligibility,
    validation_markers: offer.validationMarkers,
    verification_failure_count: 0,
    last_verification_error: null,
    last_verified_at: now,
    offer_context: offer.offerContext,
    targeting_scope: offer.targetingScope,
    targeting_text: offer.targetingText,
    auto_extracted: true,
    extraction_confidence: offer.confidence,
    extraction_method: offer.extractionMethod,
    source_page_url: pageUrl,
    source_fingerprint: offer.fingerprint,
    evidence: offer.evidence,
    last_seen_at: now,
    miss_count: 0,
    updated_at: now,
  };

  if (isRecord(existing) && existing.id) {
    const { error } = await client
      .from("commercial_offers")
      .update(payload)
      .eq("id", String(existing.id));

    if (error) {
      throw new Error(`AUTO_OFFER_UPDATE_FAILED:${error.message}`);
    }

    return "UPDATED";
  }

  const { error } = await client
    .from("commercial_offers")
    .insert({
      ...payload,
      first_seen_at: now,
    });

  if (error) {
    throw new Error(`AUTO_OFFER_INSERT_FAILED:${error.message}`);
  }

  return "PUBLISHED";
}

async function quarantineOffer(
  client: any,
  source: SourceRow,
  offer: ExtractedOffer,
  pageUrl: string,
): Promise<void> {
  const now = new Date().toISOString();

  const { data: existing, error: lookupError } = await client
    .from("commercial_offer_candidates")
    .select("id,status")
    .eq("source_id", source.id)
    .eq("candidate_hash", offer.fingerprint)
    .maybeSingle();

  if (lookupError) {
    throw new Error(`CANDIDATE_LOOKUP_FAILED:${lookupError.message}`);
  }

  const payload = {
    excerpt: `${offer.title} — ${offer.summary}`.slice(0, 400),
    detected_labels: [
      offer.category,
      offer.benefitKind,
      offer.offerContext,
      offer.targetingScope,
    ],
    last_seen_at: now,
    structured_payload: {
      title: offer.title,
      summary: offer.summary,
      category: offer.category,
      offer_context: offer.offerContext,
      targeting_scope: offer.targetingScope,
      benefit_kind: offer.benefitKind,
      benefit_label: offer.benefitLabel,
      price_amount: offer.priceAmount,
      original_price_amount: offer.originalPriceAmount,
      starts_at: offer.startsAt,
      ends_at: offer.endsAt,
      brands: offer.brands,
      model_patterns: offer.modelPatterns,
      confidence: offer.confidence,
      official_url: offer.officialUrl,
      evidence: offer.evidence,
    },
    extraction_confidence: offer.confidence,
    extraction_method: offer.extractionMethod,
    rejection_reasons: offer.rejectionReasons,
    source_page_url: pageUrl,
    metadata: {
      automatic_publication: false,
      generic_engine_version: 3,
    },
  };

  if (isRecord(existing) && existing.id) {
    const updatePayload = String(existing.status) === "PENDING_REVIEW"
      ? payload
      : {
          ...payload,
          status: existing.status,
        };

    const { error } = await client
      .from("commercial_offer_candidates")
      .update(updatePayload)
      .eq("id", String(existing.id));

    if (error) {
      throw new Error(`CANDIDATE_UPDATE_FAILED:${error.message}`);
    }
    return;
  }

  const { error } = await client
    .from("commercial_offer_candidates")
    .insert({
      source_id: source.id,
      candidate_hash: offer.fingerprint,
      status: "PENDING_REVIEW",
      ...payload,
    });

  if (error) {
    throw new Error(`CANDIDATE_INSERT_FAILED:${error.message}`);
  }
}

async function markMissingAutomaticOffers(
  client: any,
  source: SourceRow,
  pageUrl: string,
  seenFingerprints: Set<string>,
): Promise<void> {
  const { data, error } = await client
    .from("commercial_offers")
    .select("id,source_fingerprint,miss_count,status")
    .eq("source_id", source.id)
    .eq("source_page_url", pageUrl)
    .eq("auto_extracted", true);

  if (error) {
    throw new Error(`AUTO_OFFER_STALE_READ_FAILED:${error.message}`);
  }

  for (const row of data ?? []) {
    if (!isRecord(row)) continue;

    const fingerprint = String(row.source_fingerprint ?? "");
    if (fingerprint && seenFingerprints.has(fingerprint)) continue;

    const missCount = integerInRange(row.miss_count, 0, 0, 1_000) + 1;
    const nextStatus = missCount >= 2 && row.status === "ACTIVE"
      ? "REVIEW_REQUIRED"
      : row.status;

    const { error: updateError } = await client
      .from("commercial_offers")
      .update({
        miss_count: missCount,
        status: nextStatus,
        last_verification_error: "AUTO_EXTRACTION_NOT_FOUND",
        updated_at: new Date().toISOString(),
      })
      .eq("id", String(row.id));

    if (updateError) {
      throw new Error(
        `AUTO_OFFER_STALE_UPDATE_FAILED:${updateError.message}`,
      );
    }
  }
}

async function verifyManualOffers(
  client: any,
  source: SourceRow,
  pageUrl: string,
  normalizedText: string,
): Promise<{ verified: number; reviewed: number }> {
  const { data, error } = await client
    .from("commercial_offers")
    .select(
      "id,status,ends_at,official_url,source_page_url," +
        "validation_markers,verification_failure_count",
    )
    .eq("source_id", source.id)
    .eq("auto_extracted", false);

  if (error) {
    throw new Error(`MANUAL_OFFERS_READ_FAILED:${error.message}`);
  }

  let verified = 0;
  let reviewed = 0;

  for (const row of data ?? []) {
    if (!isRecord(row)) continue;

    const rowUrl = String(
      row.source_page_url ?? row.official_url ?? "",
    );

    if (rowUrl && rowUrl !== pageUrl) continue;

    const markers = Array.isArray(row.validation_markers)
      ? row.validation_markers.map(String)
      : [];

    if (markers.length === 0) continue;

    const missing = markers.filter((marker) => {
      const normalized = normalizeText(marker);
      return normalized && !normalizedText.includes(normalized);
    });

    if (missing.length === 0) {
      const { error: updateError } = await client
        .from("commercial_offers")
        .update({
          status: "ACTIVE",
          last_verified_at: new Date().toISOString(),
          verification_failure_count: 0,
          last_verification_error: null,
          updated_at: new Date().toISOString(),
        })
        .eq("id", String(row.id));

      if (updateError) {
        throw new Error(
          `MANUAL_OFFER_UPDATE_FAILED:${updateError.message}`,
        );
      }

      verified += 1;
      continue;
    }

    const failureCount = integerInRange(
      row.verification_failure_count,
      0,
      0,
      1_000,
    ) + 1;
    const status = failureCount >= 2
      ? "REVIEW_REQUIRED"
      : String(row.status ?? "ACTIVE");

    const { error: updateError } = await client
      .from("commercial_offers")
      .update({
        status,
        verification_failure_count: failureCount,
        last_verification_error:
          `MISSING_MARKERS:${missing.slice(0, 4).join("|")}`.slice(
            0,
            500,
          ),
        updated_at: new Date().toISOString(),
      })
      .eq("id", String(row.id));

    if (updateError) {
      throw new Error(
        `MANUAL_OFFER_REVIEW_FAILED:${updateError.message}`,
      );
    }

    if (status === "REVIEW_REQUIRED") reviewed += 1;
  }

  return { verified, reviewed };
}

async function storeDiscoveredLinks(
  client: any,
  source: SourceRow,
  task: CrawlTargetRow,
  links: ReturnType<typeof extractOfferLinks>,
): Promise<number> {
  let stored = 0;
  const now = new Date().toISOString();

  for (const link of links) {
    const hash = await sha256Hex(link.url);

    const { data: existing, error: lookupError } = await client
      .from("commercial_offer_discovered_urls")
      .select("id,status")
      .eq("source_id", source.id)
      .eq("url_hash", hash)
      .maybeSingle();

    if (lookupError) continue;

    const discoveredPayload = {
      discovered_url: link.url,
      link_title: link.title,
      discovery_score: link.score,
      last_seen_at: now,
      metadata: {
        parent_url: task.target_url,
        source_depth: task.depth,
        generic_engine_version: 3,
        automatic_publication: false,
      },
    };

    if (isRecord(existing) && existing.id) {
      await client
        .from("commercial_offer_discovered_urls")
        .update(discoveredPayload)
        .eq("id", String(existing.id));
    } else {
      await client
        .from("commercial_offer_discovered_urls")
        .insert({
          source_id: source.id,
          url_hash: hash,
          status: "PENDING_REVIEW",
          ...discoveredPayload,
        });
    }

    if (
      task.depth < source.crawl_depth &&
      link.score >= 55
    ) {
      const { data: targetExisting, error: targetLookupError } =
        await client
          .from("commercial_offer_crawl_targets")
          .select("id,status")
          .eq("source_id", source.id)
          .eq("url_hash", hash)
          .maybeSingle();

      if (!targetLookupError) {
        const targetPayload = {
          target_url: link.url,
          target_kind: "DISCOVERED",
          depth: task.depth + 1,
          priority: Math.max(1, 45 - Math.floor(link.score / 4)),
          check_frequency_hours:
            source.source_purpose === "CURRENT_VEHICLE" ? 24 : 48,
          next_check_at: now,
          parent_url: task.target_url,
          metadata: {
            discovery_score: link.score,
            link_title: link.title,
          },
          updated_at: now,
        };

        if (isRecord(targetExisting) && targetExisting.id) {
          if (String(targetExisting.status) !== "BLOCKED") {
            await client
              .from("commercial_offer_crawl_targets")
              .update({
                ...targetPayload,
                status: "ACTIVE",
              })
              .eq("id", String(targetExisting.id));
          }
        } else {
          await client
            .from("commercial_offer_crawl_targets")
            .insert({
              source_id: source.id,
              url_hash: hash,
              status: "ACTIVE",
              ...targetPayload,
            });
        }
      }
    }

    stored += 1;
  }

  return stored;
}

async function processTask(
  client: any,
  task: CrawlTargetRow,
  source: SourceRow,
  knownVehicles: KnownVehicle[],
): Promise<TaskOutcome> {
  try {
    const fetched = await fetchPage(
      task.target_url,
      source.allowed_hostnames,
    );

    const sourceDefinition = extractionSource(source);
    const shouldExtract = !(
      task.target_kind === "ROOT" &&
      source.monitoring_mode === "LINK_DISCOVERY_ONLY"
    );

    const extracted = shouldExtract
      ? await extractOffers(
          fetched.html,
          fetched.finalUrl.toString(),
          sourceDefinition,
          knownVehicles,
        )
      : [];

    let published = 0;
    let updated = 0;
    let candidates = 0;
    let highConfidence = 0;
    const seenFingerprints = new Set<string>();

    for (const offer of extracted) {
      seenFingerprints.add(offer.fingerprint);
      if (offer.confidence >= source.auto_publish_threshold) {
        highConfidence += 1;
      }

      if (offer.publishable) {
        const result = await publishOffer(
          client,
          source,
          offer,
          fetched.finalUrl.toString(),
        );

        if (result === "PUBLISHED") published += 1;
        else updated += 1;
      } else {
        await quarantineOffer(
          client,
          source,
          offer,
          fetched.finalUrl.toString(),
        );
        candidates += 1;
      }
    }

    if (shouldExtract) {
      await markMissingAutomaticOffers(
        client,
        source,
        fetched.finalUrl.toString(),
        seenFingerprints,
      );
    }

    const manual = await verifyManualOffers(
      client,
      source,
      fetched.finalUrl.toString(),
      fetched.normalizedText,
    );

    const links = extractOfferLinks(
      fetched.html,
      fetched.finalUrl.toString(),
      source.allowed_hostnames,
    );

    const discoveredUrls = await storeDiscoveredLinks(
      client,
      source,
      task,
      links,
    );

    const now = new Date().toISOString();

    const { error: taskUpdateError } = await client
      .from("commercial_offer_crawl_targets")
      .update({
        status: "ACTIVE",
        robots_status: fetched.robotsStatus,
        last_http_status: fetched.status,
        last_checked_at: now,
        last_success_at: now,
        failure_count: 0,
        last_error_code: null,
        content_hash: fetched.contentHash,
        next_check_at: nextCheckIso(task.check_frequency_hours),
        metadata: {
          target_kind: task.target_kind,
          extraction_count: extracted.length,
          published_count: published,
          updated_count: updated,
          candidate_count: candidates,
          discovered_url_count: discoveredUrls,
          final_url: fetched.finalUrl.toString(),
        },
        updated_at: now,
      })
      .eq("id", task.id);

    if (taskUpdateError) {
      throw new Error(
        `CRAWL_TARGET_UPDATE_FAILED:${taskUpdateError.message}`,
      );
    }

    const { error: sourceUpdateError } = await client
      .from("commercial_offer_sources")
      .update({
        status: "ACTIVE",
        robots_status: fetched.robotsStatus,
        last_http_status: fetched.status,
        last_checked_at: now,
        last_success_at: now,
        failure_count: 0,
        last_error_code: null,
        content_hash: task.target_kind === "ROOT"
          ? fetched.contentHash
          : source.content_hash,
        last_extraction_at: now,
        extracted_offer_count:
          published + updated + candidates,
        metadata: {
          ...source.metadata,
          generic_engine_version: 3,
          last_target_url: fetched.finalUrl.toString(),
          last_published_count: published,
          last_updated_count: updated,
          last_candidate_count: candidates,
          last_discovered_url_count: discoveredUrls,
        },
        updated_at: now,
      })
      .eq("id", source.id);

    if (sourceUpdateError) {
      throw new Error(
        `SOURCE_UPDATE_FAILED:${sourceUpdateError.message}`,
      );
    }

    return {
      sourceKey: source.source_key,
      targetUrl: task.target_url,
      success: true,
      published,
      updated,
      candidates,
      discoveredUrls,
      verifiedManualOffers: manual.verified,
      reviewedManualOffers: manual.reviewed,
      highConfidence,
    };
  } catch (error) {
    const errorCode = safeError(error).split(":")[0].slice(0, 160);
    const failureCount = task.failure_count + 1;
    const blocked = errorCode === "ROBOTS_DISALLOWED";
    const now = new Date().toISOString();

    await client
      .from("commercial_offer_crawl_targets")
      .update({
        status: blocked ? "BLOCKED" : "ERROR",
        robots_status: blocked ? "DISALLOWED" : "UNAVAILABLE",
        last_checked_at: now,
        failure_count: failureCount,
        last_error_code: errorCode,
        next_check_at: blocked
          ? null
          : nextCheckIso(task.check_frequency_hours, failureCount),
        updated_at: now,
      })
      .eq("id", task.id);

    await client
      .from("commercial_offer_sources")
      .update({
        status: blocked ? "BLOCKED" : "ERROR",
        last_checked_at: now,
        failure_count: source.failure_count + 1,
        last_error_code: errorCode,
        updated_at: now,
      })
      .eq("id", source.id);

    return {
      sourceKey: source.source_key,
      targetUrl: task.target_url,
      success: false,
      published: 0,
      updated: 0,
      candidates: 0,
      discoveredUrls: 0,
      verifiedManualOffers: 0,
      reviewedManualOffers: 0,
      highConfidence: 0,
      errorCode,
    };
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: responseHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  let client: any = null;
  let lockAcquired = false;
  let runId: string | null = null;

  try {
    client = adminClient();

    const suppliedSecret =
      request.headers.get("x-sync-secret")?.trim() ?? "";

    if (!suppliedSecret || suppliedSecret.length < 32) {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }

    const { data: secretValid, error: secretError } = await client.rpc(
      "validate_commercial_offer_sync_secret",
      { p_candidate: suppliedSecret },
    );

    if (secretError || secretValid !== true) {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }

    let body: JsonMap = {};
    try {
      body = await readJsonBody(request);
    } catch {
      body = {};
    }

    const trigger = String(body.trigger ?? "scheduled-v3")
      .trim()
      .toUpperCase()
      .slice(0, 80);
    const batchSize = integerInRange(
      body.batch_size,
      4,
      1,
      MAX_BATCH_SIZE,
    );
    const force = asBoolean(body.force);

    const { data: acquired, error: lockError } = await client.rpc(
      "acquire_commercial_offer_sync_lock",
    );

    if (lockError) {
      throw new Error(`SYNC_LOCK_FAILED:${lockError.message}`);
    }

    lockAcquired = acquired === true;

    if (!lockAcquired && !force) {
      await client.from("commercial_offer_sync_runs").insert({
        status: "SKIPPED",
        trigger_type: trigger,
        error_summary: "SYNC_ALREADY_RUNNING",
        finished_at: new Date().toISOString(),
      });

      return jsonResponse({
        success: true,
        status: "SKIPPED",
        reason: "SYNC_ALREADY_RUNNING",
      });
    }

    if (!lockAcquired && force) {
      throw new Error("SYNC_ALREADY_RUNNING");
    }

    const { data: run, error: runError } = await client
      .from("commercial_offer_sync_runs")
      .insert({
        status: "RUNNING",
        trigger_type: trigger,
      })
      .select("id")
      .single();

    if (runError || !isRecord(run)) {
      throw new Error(
        `SYNC_RUN_CREATE_FAILED:${runError?.message ?? ""}`,
      );
    }

    runId = String(run.id ?? "") || null;

    const [tasks, knownVehicles] = await Promise.all([
      loadDueTasks(client, batchSize),
      loadKnownVehicles(client),
    ]);

    if (tasks.length === 0) {
      if (runId) {
        await client
          .from("commercial_offer_sync_runs")
          .update({
            status: "SUCCESS",
            source_count: 0,
            success_count: 0,
            failure_count: 0,
            crawl_target_count: 0,
            finished_at: new Date().toISOString(),
          })
          .eq("id", runId);
      }

      return jsonResponse({
        success: true,
        status: "SUCCESS",
        reason: "NO_DUE_TARGETS",
      });
    }

    const outcomes: TaskOutcome[] = [];

    for (const item of tasks) {
      outcomes.push(
        await processTask(
          client,
          item.task,
          item.source,
          knownVehicles,
        ),
      );

      await new Promise((resolve) => setTimeout(resolve, 350));
    }

    const successCount = outcomes.filter((item) => item.success).length;
    const failureCount = outcomes.length - successCount;
    const publishedCount = outcomes.reduce(
      (sum, item) => sum + item.published,
      0,
    );
    const updatedCount = outcomes.reduce(
      (sum, item) => sum + item.updated,
      0,
    );
    const candidateCount = outcomes.reduce(
      (sum, item) => sum + item.candidates,
      0,
    );
    const discoveredUrlCount = outcomes.reduce(
      (sum, item) => sum + item.discoveredUrls,
      0,
    );
    const verifiedOfferCount = outcomes.reduce(
      (sum, item) => sum + item.verifiedManualOffers,
      0,
    );
    const reviewOfferCount = outcomes.reduce(
      (sum, item) => sum + item.reviewedManualOffers,
      0,
    );
    const highConfidenceCount = outcomes.reduce(
      (sum, item) => sum + item.highConfidence,
      0,
    );

    const status = successCount === 0
      ? "FAILED"
      : failureCount === 0
      ? "SUCCESS"
      : "PARTIAL";

    const errors = outcomes
      .filter((item) => !item.success)
      .map((item) =>
        `${item.sourceKey}:${item.errorCode ?? "UNKNOWN"}`
      )
      .join("; ")
      .slice(0, 1_500);

    if (runId) {
      await client
        .from("commercial_offer_sync_runs")
        .update({
          status,
          source_count: new Set(
            outcomes.map((item) => item.sourceKey),
          ).size,
          success_count: successCount,
          failure_count: failureCount,
          verified_offer_count: verifiedOfferCount,
          review_offer_count: reviewOfferCount,
          candidate_count: candidateCount,
          discovered_url_count: discoveredUrlCount,
          crawl_target_count: outcomes.length,
          auto_published_count: publishedCount,
          auto_updated_count: updatedCount,
          high_confidence_count: highConfidenceCount,
          error_summary: errors || null,
          finished_at: new Date().toISOString(),
        })
        .eq("id", runId);
    }

    return jsonResponse({
      success: status !== "FAILED",
      status,
      target_count: outcomes.length,
      success_count: successCount,
      failure_count: failureCount,
      auto_published_count: publishedCount,
      auto_updated_count: updatedCount,
      candidate_count: candidateCount,
      discovered_url_count: discoveredUrlCount,
      verified_manual_offer_count: verifiedOfferCount,
      reviewed_manual_offer_count: reviewOfferCount,
      high_confidence_count: highConfidenceCount,
      known_vehicle_model_count: knownVehicles.length,
      targets: outcomes.map((item) => ({
        source_key: item.sourceKey,
        target_url: item.targetUrl,
        success: item.success,
        published: item.published,
        updated: item.updated,
        candidates: item.candidates,
        discovered_urls: item.discoveredUrls,
        error_code: item.errorCode,
      })),
    }, status === "FAILED" ? 503 : 200);
  } catch (error) {
    const message = safeError(error).slice(0, 1_500);

    if (client && runId) {
      await client
        .from("commercial_offer_sync_runs")
        .update({
          status: "FAILED",
          error_summary: message,
          finished_at: new Date().toISOString(),
        })
        .eq("id", runId);
    }

    return jsonResponse({
      success: false,
      error: message.split(":")[0],
    }, message === "UNAUTHORIZED" ? 401 : 500);
  } finally {
    if (client && lockAcquired) {
      await client.rpc("release_commercial_offer_sync_lock");
    }
  }
});
