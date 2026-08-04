import { createClient } from "npm:@supabase/supabase-js@2";
import {
  asBoolean,
  asString,
  isRecord,
  readJsonBody,
  safeError,
  sha256Hex,
  type JsonMap,
} from "../_shared/utils.ts";

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
  next_check_at: string | null;
  monitoring_mode:
    | "HTML_RULES"
    | "HTML_DISCOVERY"
    | "LINK_DISCOVERY_ONLY"
    | "ADAPTER_REQUIRED"
    | "REFERENCE_ONLY"
    | "DISABLED_BY_POLICY";
  publication_policy:
    | "VALIDATED_RULES_ONLY"
    | "QUARANTINE_ONLY"
    | "REFERENCE_ONLY";
  source_purpose:
    | "CURRENT_VEHICLE"
    | "VEHICLE_PURCHASE"
    | "FINANCE_INSURANCE"
    | "REFERENCE_ONLY"
    | "DISCOVERY_ONLY"
    | "OTHER";
};

type OfferRow = {
  id: string;
  offer_key: string;
  title: string;
  status: string;
  ends_at: string | null;
  validation_markers: string[];
  verification_failure_count: number;
};

type FetchResult = {
  html: string;
  normalizedText: string;
  finalUrl: URL;
  status: number;
  contentHash: string;
  robotsStatus: "ALLOWED" | "DISALLOWED" | "UNAVAILABLE";
};

type SourceOutcome = {
  sourceKey: string;
  success: boolean;
  verifiedOffers: number;
  reviewOffers: number;
  candidates: number;
  discoveredUrls: number;
  errorCode?: string;
};

type SourceLoadResult = {
  sources: SourceRow[];
  catalogV2: boolean;
};

type DiscoveredLink = {
  url: string;
  title: string;
  score: number;
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
      // The legacy variable below remains a supported fallback.
    }
  }

  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
}

const SERVICE_ROLE_KEY = readAdminKey();

const MAX_HTML_BYTES = 2_000_000;
const MAX_CANDIDATES_PER_SOURCE = 25;
const MAX_DISCOVERED_URLS_PER_SOURCE = 30;
const MAX_BATCH_SIZE = 5;
const FETCH_TIMEOUT_MS = 12_000;
const BOT_NAME = "AutoClairOffersBot";
const USER_AGENT =
  "AutoClairOffersBot/1.0 (+official-offer-verification; contact: AutoClair)";

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

function adminClient() {
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
        "X-Client-Info": "autoclair-commercial-offers-sync/1.0",
      },
    },
  });
}

function normalizedHostname(value: string): string {
  return value.trim().toLowerCase().replace(/\.$/, "");
}

function hostnameAllowed(
  hostname: string,
  allowedHostnames: string[],
): boolean {
  const normalized = normalizedHostname(hostname);

  return allowedHostnames.some((allowed) => {
    const expected = normalizedHostname(allowed);
    return normalized === expected;
  });
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

function decodeHtmlEntities(value: string): string {
  const named: Record<string, string> = {
    amp: "&",
    apos: "'",
    copy: "©",
    euro: "€",
    gt: ">",
    laquo: "«",
    lt: "<",
    nbsp: " ",
    ndash: "–",
    mdash: "—",
    quot: '"',
    raquo: "»",
    reg: "®",
  };

  return value
    .replace(
      /&#x([0-9a-f]+);/gi,
      (_, hexadecimal: string) =>
        String.fromCodePoint(Number.parseInt(hexadecimal, 16)),
    )
    .replace(
      /&#([0-9]+);/g,
      (_, decimal: string) =>
        String.fromCodePoint(Number.parseInt(decimal, 10)),
    )
    .replace(
      /&([a-z]+);/gi,
      (entity, name: string) => named[name.toLowerCase()] ?? entity,
    );
}

function stripHtml(html: string): string {
  const withoutExecutableContent = html
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(
      /<(script|style|noscript|svg|template)\b[^>]*>[\s\S]*?<\/\1>/gi,
      " ",
    )
    .replace(/<(br|hr)\b[^>]*>/gi, "\n")
    .replace(/<\/(p|li|div|section|article|h[1-6]|tr)>/gi, "\n")
    .replace(/<[^>]+>/g, " ");

  return decodeHtmlEntities(withoutExecutableContent);
}

function normalizeText(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[’‘`´]/g, "'")
    .replace(/[^a-z0-9%€]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function extractCandidateBlocks(html: string): string[] {
  const blocks: string[] = [];
  const blockPattern =
    /<(h[1-6]|p|li|article|section)\b[^>]*>([\s\S]*?)<\/\1>/gi;

  for (const match of html.matchAll(blockPattern)) {
    const plain = stripHtml(match[2] ?? "")
      .replace(/\s+/g, " ")
      .trim();

    if (plain.length < 45 || plain.length > 900) continue;

    const normalized = normalizeText(plain);
    const hasCommercialSignal =
      /\b(offre|promotion|remise|reduction|gratuit|offert|forfait|a partir de|economisez)\b/
        .test(normalized) ||
      /\b\d{1,3}\s*%\b/.test(normalized) ||
      /\b\d{1,5}(?:[,.]\d{1,2})?\s*(?:€|eur)\b/.test(normalized);

    const currentYear = new Date().getUTCFullYear();
    const hasCurrentDate =
      normalized.includes(String(currentYear)) ||
      normalized.includes(String(currentYear + 1)) ||
      /\b(31|30|29|28)\s+(?:aout|decembre|septembre|octobre|novembre)\b/
        .test(normalized);

    if (hasCommercialSignal && hasCurrentDate) {
      blocks.push(plain);
    }
  }

  return Array.from(new Set(blocks)).slice(
    0,
    MAX_CANDIDATES_PER_SOURCE,
  );
}

function candidateLabels(value: string): string[] {
  const normalized = normalizeText(value);
  const labels = new Set<string>();

  if (/\b\d{1,3}\s*%\b/.test(normalized)) labels.add("PERCENT");
  if (/\b(gratuit|offert)\b/.test(normalized)) labels.add("FREE");
  if (/\ba partir de\b/.test(normalized)) labels.add("FROM_PRICE");
  if (/\b(entretien|revision|vidange)\b/.test(normalized)) {
    labels.add("MAINTENANCE");
  }
  if (/\b(pneu|pneumatique)\b/.test(normalized)) labels.add("TYRES");
  if (/\b(climatisation|clim)\b/.test(normalized)) {
    labels.add("CLIMATE");
  }
  if (/\b(controle technique|contre visite)\b/.test(normalized)) {
    labels.add("INSPECTION");
  }
  if (/\b(accessoire|barres de toit)\b/.test(normalized)) {
    labels.add("ACCESSORIES");
  }
  const currentYear = new Date().getUTCFullYear();

  if (normalized.includes(String(currentYear))) {
    labels.add(`YEAR_${currentYear}`);
  }
  if (normalized.includes(String(currentYear + 1))) {
    labels.add(`YEAR_${currentYear + 1}`);
  }

  return Array.from(labels);
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

function cleanDiscoveredUrl(
  rawHref: string,
  baseUrl: URL,
  allowedHostnames: string[],
): URL | null {
  const trimmed = rawHref.trim();

  if (
    !trimmed ||
    trimmed.startsWith("#") ||
    trimmed.startsWith("mailto:") ||
    trimmed.startsWith("tel:") ||
    trimmed.startsWith("javascript:")
  ) {
    return null;
  }

  let url: URL;

  try {
    url = new URL(trimmed, baseUrl);
  } catch {
    return null;
  }

  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    !hostnameAllowed(url.hostname, allowedHostnames)
  ) {
    return null;
  }

  url.hash = "";

  const trackingKeys = [
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    "gclid",
    "fbclid",
    "msclkid",
  ];

  for (const key of trackingKeys) {
    url.searchParams.delete(key);
  }

  if (url.toString().length > 1_000) return null;

  return url;
}

function discoveredLinkScore(
  url: URL,
  title: string,
): number {
  const value = normalizeText(
    `${url.pathname} ${url.search} ${title}`,
  );

  let score = 0;

  const weightedSignals: Array<[RegExp, number]> = [
    [/\b(offre|offres|promotion|promotions|promo)\b/, 45],
    [/\b(entretien|revision|service|atelier|apres vente)\b/, 30],
    [/\b(forfait|remise|reduction|avantage|bon plan)\b/, 25],
    [/\b(financement|leasing|loa|lld|reprise)\b/, 20],
    [/\b(stock|disponible|vehicule neuf|occasion)\b/, 12],
    [/\b(pneu|batterie|climatisation|frein|pare brise)\b/, 20],
  ];

  for (const [pattern, weight] of weightedSignals) {
    if (pattern.test(value)) score += weight;
  }

  const currentYear = new Date().getUTCFullYear();
  if (
    value.includes(String(currentYear)) ||
    value.includes(String(currentYear + 1))
  ) {
    score += 8;
  }

  if (url.pathname === "/" || url.pathname.length < 3) {
    score -= 20;
  }

  return Math.max(0, Math.min(100, score));
}

function extractOfferLinks(
  html: string,
  finalUrl: URL,
  allowedHostnames: string[],
): DiscoveredLink[] {
  const candidates = new Map<string, DiscoveredLink>();
  const linkPattern =
    /<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;

  for (const match of html.matchAll(linkPattern)) {
    const url = cleanDiscoveredUrl(
      match[1] ?? "",
      finalUrl,
      allowedHostnames,
    );

    if (!url) continue;

    const title = stripHtml(match[2] ?? "")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 220);

    const score = discoveredLinkScore(url, title);

    if (score < 35) continue;

    const key = url.toString();
    const current = candidates.get(key);

    if (!current || score > current.score) {
      candidates.set(key, {
        url: key,
        title,
        score,
      });
    }
  }

  return Array.from(candidates.values())
    .sort((a, b) => b.score - a.score || a.url.localeCompare(b.url))
    .slice(0, MAX_DISCOVERED_URLS_PER_SOURCE);
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

async function checkRobots(
  sourceUrl: URL,
  allowedHostnames: string[],
): Promise<"ALLOWED" | "DISALLOWED" | "UNAVAILABLE"> {
  const robotsUrl = new URL("/robots.txt", sourceUrl.origin);

  try {
    const response = await fetchWithTimeout(robotsUrl, {
      method: "GET",
      headers: {
        Accept: "text/plain,*/*;q=0.1",
        "User-Agent": USER_AGENT,
      },
    });

    if (response.status === 404) return "ALLOWED";
    if (!response.ok) return "UNAVAILABLE";

    const finalUrl = new URL(response.url || robotsUrl.toString());

    if (!hostnameAllowed(finalUrl.hostname, allowedHostnames)) {
      return "DISALLOWED";
    }

    const robotsText = await response.text();
    const rules = parseRobotsRules(robotsText, BOT_NAME);

    return robotsAllows(rules, sourceUrl)
      ? "ALLOWED"
      : "DISALLOWED";
  } catch {
    return "UNAVAILABLE";
  }
}

async function fetchOfficialPage(
  source: SourceRow,
): Promise<FetchResult> {
  const url = validatedHttpsUrl(
    source.source_url,
    source.allowed_hostnames,
  );

  const robotsStatus = await checkRobots(
    url,
    source.allowed_hostnames,
  );

  if (robotsStatus === "DISALLOWED") {
    throw new Error("ROBOTS_DISALLOWED");
  }

  const response = await fetchWithTimeout(url, {
    method: "GET",
    headers: {
      Accept: "text/html,application/xhtml+xml",
      "Accept-Language": "fr-FR,fr;q=0.9",
      "User-Agent": USER_AGENT,
    },
  });

  const finalUrl = new URL(response.url || url.toString());

  if (!hostnameAllowed(finalUrl.hostname, source.allowed_hostnames)) {
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

  const normalizedText = normalizeText(stripHtml(html));

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

function dateHasExpired(value: string | null): boolean {
  if (!value) return false;

  const end = new Date(`${value}T23:59:59Z`);
  return !Number.isNaN(end.getTime()) && end.getTime() < Date.now();
}

function missingMarkers(
  normalizedText: string,
  markers: string[],
): string[] {
  return markers.filter((marker) => {
    const normalizedMarker = normalizeText(marker);
    return normalizedMarker && !normalizedText.includes(normalizedMarker);
  });
}

async function insertCandidates(
  client: ReturnType<typeof adminClient>,
  source: SourceRow,
  html: string,
  knownOffers: OfferRow[],
): Promise<number> {
  const blocks = extractCandidateBlocks(html);
  let inserted = 0;

  for (const block of blocks) {
    const normalized = normalizeText(block);

    const alreadyCovered = knownOffers.some((offer) => {
      const normalizedTitle = normalizeText(offer.title);
      if (
        normalizedTitle.length >= 10 &&
        normalized.includes(normalizedTitle)
      ) {
        return true;
      }

      const markers = Array.isArray(offer.validation_markers)
        ? offer.validation_markers
            .map(normalizeText)
            .filter((marker) => marker.length >= 8)
        : [];

      if (markers.length === 0) return false;

      const matchCount = markers.filter((marker) =>
        normalized.includes(marker)
      ).length;

      return matchCount >= Math.min(2, markers.length);
    });

    if (alreadyCovered) continue;

    const hash = await sha256Hex({
      source: source.source_key,
      block: normalized,
    });

    const now = new Date().toISOString();
    const candidatePayload = {
      excerpt: block.slice(0, 400),
      detected_labels: candidateLabels(block),
      last_seen_at: now,
      metadata: {
        source_url: source.source_url,
        automatic_publication: false,
      },
    };

    const { data: existing, error: existingError } = await client
      .from("commercial_offer_candidates")
      .select("id,status")
      .eq("source_id", source.id)
      .eq("candidate_hash", hash)
      .maybeSingle();

    if (existingError) continue;

    if (existing?.id) {
      const { error } = await client
        .from("commercial_offer_candidates")
        .update(candidatePayload)
        .eq("id", existing.id);

      if (!error) inserted += 1;
      continue;
    }

    const { error } = await client
      .from("commercial_offer_candidates")
      .insert({
        source_id: source.id,
        candidate_hash: hash,
        status: "PENDING_REVIEW",
        ...candidatePayload,
      });

    if (!error) inserted += 1;
  }

  return inserted;
}

async function insertDiscoveredUrls(
  client: ReturnType<typeof adminClient>,
  source: SourceRow,
  links: DiscoveredLink[],
  catalogV2: boolean,
): Promise<number> {
  if (!catalogV2 || links.length === 0) return 0;

  let stored = 0;

  for (const link of links) {
    const urlHash = await sha256Hex({
      source: source.source_key,
      url: link.url,
    });

    const now = new Date().toISOString();
    const payload = {
      discovered_url: link.url,
      link_title: link.title,
      discovery_score: link.score,
      last_seen_at: now,
      metadata: {
        source_url: source.source_url,
        automatic_publication: false,
        monitoring_mode: source.monitoring_mode,
      },
    };

    const { data: existing, error: readError } = await client
      .from("commercial_offer_discovered_urls")
      .select("id,status")
      .eq("source_id", source.id)
      .eq("url_hash", urlHash)
      .maybeSingle();

    if (readError) {
      const message = readError.message.toLowerCase();

      if (
        message.includes("commercial_offer_discovered_urls") &&
        message.includes("does not exist")
      ) {
        return 0;
      }

      continue;
    }

    if (existing?.id) {
      const { error } = await client
        .from("commercial_offer_discovered_urls")
        .update(payload)
        .eq("id", existing.id);

      if (!error) stored += 1;
      continue;
    }

    const { error } = await client
      .from("commercial_offer_discovered_urls")
      .insert({
        source_id: source.id,
        url_hash: urlHash,
        status: "PENDING_REVIEW",
        ...payload,
      });

    if (!error) stored += 1;
  }

  return stored;
}

function nextCheckIso(
  source: SourceRow,
  success: boolean,
): string {
  const baseHours = integerInRange(
    source.check_frequency_hours,
    72,
    6,
    720,
  );

  const hours = success
    ? baseHours
    : Math.max(12, Math.min(168, Math.round(baseHours / 2)));

  return new Date(Date.now() + hours * 3_600_000).toISOString();
}

async function processSource(
  client: ReturnType<typeof adminClient>,
  source: SourceRow,
  catalogV2: boolean,
): Promise<SourceOutcome> {
  try {
    const fetched = await fetchOfficialPage(source);

    const { data: rawOffers, error: offerError } = await client
      .from("commercial_offers")
      .select(
        "id,offer_key,title,status,ends_at,validation_markers," +
          "verification_failure_count",
      )
      .eq("source_id", source.id);

    if (offerError) throw new Error(`OFFERS_READ_FAILED:${offerError.message}`);

    const offers = (rawOffers ?? []) as OfferRow[];
    let verifiedOffers = 0;
    let reviewOffers = 0;
    for (const offer of offers) {
      if (dateHasExpired(offer.ends_at)) {
        const { error } = await client
          .from("commercial_offers")
          .update({
            status: "EXPIRED",
            last_verification_error: null,
            updated_at: new Date().toISOString(),
          })
          .eq("id", offer.id);

        if (error) {
          throw new Error(`OFFER_UPDATE_FAILED:${error.message}`);
        }
        continue;
      }

      const markers = Array.isArray(offer.validation_markers)
        ? offer.validation_markers
        : [];

      const missing = missingMarkers(
        fetched.normalizedText,
        markers,
      );

      if (markers.length > 0 && missing.length === 0) {
        const { error } = await client
          .from("commercial_offers")
          .update({
            status: "ACTIVE",
            last_verified_at: new Date().toISOString(),
            verification_failure_count: 0,
            last_verification_error: null,
            updated_at: new Date().toISOString(),
          })
          .eq("id", offer.id);

        if (error) {
          throw new Error(`OFFER_UPDATE_FAILED:${error.message}`);
        }

        verifiedOffers += 1;
        continue;
      }

      const failureCount =
        Math.max(0, offer.verification_failure_count ?? 0) + 1;

      const nextStatus = failureCount >= 2
        ? "REVIEW_REQUIRED"
        : offer.status;

      const { error } = await client
        .from("commercial_offers")
        .update({
          status: nextStatus,
          verification_failure_count: failureCount,
          last_verification_error:
            `MISSING_MARKERS:${missing.slice(0, 4).join("|")}`.slice(
              0,
              500,
            ),
          updated_at: new Date().toISOString(),
        })
        .eq("id", offer.id);

      if (error) {
        throw new Error(`OFFER_UPDATE_FAILED:${error.message}`);
      }

      if (nextStatus === "REVIEW_REQUIRED") reviewOffers += 1;
    }

    const candidates = source.monitoring_mode ===
          "LINK_DISCOVERY_ONLY" ||
        source.publication_policy === "REFERENCE_ONLY"
      ? 0
      : await insertCandidates(
          client,
          source,
          fetched.html,
          offers,
        );

    const discoveredUrls = await insertDiscoveredUrls(
      client,
      source,
      extractOfferLinks(
        fetched.html,
        fetched.finalUrl,
        source.allowed_hostnames,
      ),
      catalogV2,
    );

    const sourceUpdatePayload: JsonMap = {
      status: source.source_purpose === "CURRENT_VEHICLE"
        ? "ACTIVE"
        : "PAUSED",
      robots_status: fetched.robotsStatus,
      last_http_status: fetched.status,
      last_checked_at: new Date().toISOString(),
      last_success_at: new Date().toISOString(),
      failure_count: 0,
      content_hash: fetched.contentHash,
      last_error_code: null,
      metadata: {
        ...source.metadata,
        final_url: fetched.finalUrl.toString(),
        content_changed: source.content_hash !== fetched.contentHash,
        fetched_by: BOT_NAME,
        catalog_version: catalogV2 ? 2 : 1,
      },
      updated_at: new Date().toISOString(),
    };

    if (catalogV2) {
      sourceUpdatePayload.next_check_at = nextCheckIso(
        source,
        true,
      );
    }

    const { error: sourceUpdateError } = await client
      .from("commercial_offer_sources")
      .update(sourceUpdatePayload)
      .eq("id", source.id);

    if (sourceUpdateError) {
      throw new Error(
        `SOURCE_UPDATE_FAILED:${sourceUpdateError.message}`,
      );
    }

    return {
      sourceKey: source.source_key,
      success: true,
      verifiedOffers,
      reviewOffers,
      candidates,
      discoveredUrls,
    };
  } catch (error) {
    const errorCode = safeError(error).split(":")[0].slice(0, 160);
    const nextFailureCount = Math.max(0, source.failure_count ?? 0) + 1;
    const nextStatus = errorCode === "ROBOTS_DISALLOWED"
      ? "BLOCKED"
      : source.source_purpose === "CURRENT_VEHICLE"
      ? "ERROR"
      : "PAUSED";

    const failurePayload: JsonMap = {
      status: nextStatus,
      robots_status: errorCode === "ROBOTS_DISALLOWED"
        ? "DISALLOWED"
        : "UNAVAILABLE",
      last_checked_at: new Date().toISOString(),
      failure_count: nextFailureCount,
      last_error_code: errorCode,
      updated_at: new Date().toISOString(),
    };

    if (catalogV2) {
      failurePayload.next_check_at = errorCode === "ROBOTS_DISALLOWED"
        ? null
        : nextCheckIso(source, false);
    }

    await client
      .from("commercial_offer_sources")
      .update(failurePayload)
      .eq("id", source.id);

    return {
      sourceKey: source.source_key,
      success: false,
      verifiedOffers: 0,
      reviewOffers: 0,
      candidates: 0,
      discoveredUrls: 0,
      errorCode,
    };
  }
}

async function loadDueSources(
  client: ReturnType<typeof adminClient>,
  batchSize: number,
): Promise<SourceLoadResult> {
  const currentSelect =
    "id,source_key,source_name,source_url,allowed_hostnames,status," +
    "content_hash,failure_count,metadata,search_enabled," +
    "search_priority,check_frequency_hours,next_check_at," +
    "monitoring_mode,publication_policy,source_purpose";

  const currentQuery = await client
    .from("commercial_offer_sources")
    .select(currentSelect)
    .eq("search_enabled", true)
    .in("status", ["ACTIVE", "ERROR", "PAUSED"])
    .limit(500);

  if (!currentQuery.error) {
    const now = Date.now();
    const supportedModes = new Set([
      "HTML_RULES",
      "HTML_DISCOVERY",
      "LINK_DISCOVERY_ONLY",
    ]);

    const sources = ((currentQuery.data ?? []) as Array<
      Record<string, unknown>
    >)
      .map((row): SourceRow => ({
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
        failure_count: integerInRange(
          row.failure_count,
          0,
          0,
          10_000,
        ),
        metadata: isRecord(row.metadata)
          ? row.metadata as JsonMap
          : {},
        search_enabled: row.search_enabled === true,
        search_priority: integerInRange(
          row.search_priority,
          50,
          1,
          100,
        ),
        check_frequency_hours: integerInRange(
          row.check_frequency_hours,
          72,
          6,
          720,
        ),
        next_check_at: typeof row.next_check_at === "string"
          ? row.next_check_at
          : null,
        monitoring_mode: String(
          row.monitoring_mode ?? "HTML_RULES",
        ) as SourceRow["monitoring_mode"],
        publication_policy: String(
          row.publication_policy ?? "VALIDATED_RULES_ONLY",
        ) as SourceRow["publication_policy"],
        source_purpose: String(
          row.source_purpose ?? "CURRENT_VEHICLE",
        ) as SourceRow["source_purpose"],
      }))
      .filter((source) =>
        source.id &&
        source.source_key &&
        source.search_enabled &&
        supportedModes.has(source.monitoring_mode) &&
        (
          !source.next_check_at ||
          new Date(source.next_check_at).getTime() <= now
        )
      )
      .sort((a, b) => {
        const priority = a.search_priority - b.search_priority;
        if (priority !== 0) return priority;

        const aDue = a.next_check_at
          ? new Date(a.next_check_at).getTime()
          : 0;
        const bDue = b.next_check_at
          ? new Date(b.next_check_at).getTime()
          : 0;

        return aDue - bDue || a.source_key.localeCompare(b.source_key);
      })
      .slice(0, batchSize);

    return {
      sources,
      catalogV2: true,
    };
  }

  const currentError = currentQuery.error.message.toLowerCase();
  const catalogMissing =
    currentError.includes("search_enabled") ||
    currentError.includes("monitoring_mode") ||
    currentError.includes("next_check_at");

  if (!catalogMissing) {
    throw new Error(
      `SOURCES_READ_FAILED:${currentQuery.error.message}`,
    );
  }

  // Backward-compatible fallback: keeps the four V1 sources operational
  // if the V2 function is deployed before the catalog migration.
  const legacyQuery = await client
    .from("commercial_offer_sources")
    .select(
      "id,source_key,source_name,source_url,allowed_hostnames,status," +
        "content_hash,failure_count,metadata",
    )
    .in("status", ["ACTIVE", "ERROR"])
    .limit(batchSize);

  if (legacyQuery.error) {
    throw new Error(`SOURCES_READ_FAILED:${legacyQuery.error.message}`);
  }

  return {
    catalogV2: false,
    sources: ((legacyQuery.data ?? []) as Array<
      Record<string, unknown>
    >).map((row): SourceRow => ({
      id: String(row.id ?? ""),
      source_key: String(row.source_key ?? ""),
      source_name: String(row.source_name ?? ""),
      source_url: String(row.source_url ?? ""),
      allowed_hostnames: Array.isArray(row.allowed_hostnames)
        ? row.allowed_hostnames.map(String)
        : [],
      status: String(row.status ?? "ACTIVE"),
      content_hash: typeof row.content_hash === "string"
        ? row.content_hash
        : null,
      failure_count: integerInRange(
        row.failure_count,
        0,
        0,
        10_000,
      ),
      metadata: isRecord(row.metadata)
        ? row.metadata as JsonMap
        : {},
      search_enabled: true,
      search_priority: 1,
      check_frequency_hours: 24,
      next_check_at: null,
      monitoring_mode: "HTML_RULES",
      publication_policy: "VALIDATED_RULES_ONLY",
      source_purpose: "CURRENT_VEHICLE",
    })),
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: responseHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  let client: ReturnType<typeof adminClient> | null = null;
  let lockAcquired = false;
  let runId: string | null = null;

  try {
    client = adminClient();

    const suppliedSecret =
      req.headers.get("x-sync-secret")?.trim() ?? "";

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
      body = await readJsonBody(req);
    } catch {
      body = {};
    }

    const trigger =
      asString(body.trigger)?.toUpperCase() ?? "SCHEDULED";
    const force = asBoolean(body.force);
    const batchSize = integerInRange(
      body.batch_size,
      MAX_BATCH_SIZE,
      1,
      MAX_BATCH_SIZE,
    );

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
      throw new Error(`SYNC_RUN_CREATE_FAILED:${runError?.message ?? ""}`);
    }

    runId = asString(run.id);

    const sourceLoad = await loadDueSources(
      client,
      batchSize,
    );
    const sources = sourceLoad.sources;
    const outcomes: SourceOutcome[] = [];

    // Sequential retrieval avoids bursts against publishers. The batch is
    // deliberately capped at five sources to remain inside hosted runtime
    // limits even when every source reaches its network timeout.
    for (const source of sources) {
      outcomes.push(
        await processSource(
          client,
          source,
          sourceLoad.catalogV2,
        ),
      );
      await new Promise((resolve) => setTimeout(resolve, 700));
    }

    const successCount = outcomes.filter((item) => item.success).length;
    const failureCount = outcomes.length - successCount;
    const verifiedOfferCount = outcomes.reduce(
      (total, item) => total + item.verifiedOffers,
      0,
    );
    const reviewOfferCount = outcomes.reduce(
      (total, item) => total + item.reviewOffers,
      0,
    );
    const candidateCount = outcomes.reduce(
      (total, item) => total + item.candidates,
      0,
    );
    const discoveredUrlCount = outcomes.reduce(
      (total, item) => total + item.discoveredUrls,
      0,
    );

    const status = outcomes.length === 0
      ? "SKIPPED"
      : successCount === 0
      ? "FAILED"
      : failureCount === 0
      ? "SUCCESS"
      : "PARTIAL";

    const errors = outcomes
      .filter((item) => !item.success)
      .map((item) => `${item.sourceKey}:${item.errorCode ?? "UNKNOWN"}`)
      .join("; ")
      .slice(0, 1500);

    if (runId) {
      const runPayload: JsonMap = {
        status,
        source_count: outcomes.length,
        success_count: successCount,
        failure_count: failureCount,
        verified_offer_count: verifiedOfferCount,
        review_offer_count: reviewOfferCount,
        candidate_count: candidateCount,
        error_summary: errors || null,
        finished_at: new Date().toISOString(),
      };

      if (sourceLoad.catalogV2) {
        runPayload.discovered_url_count = discoveredUrlCount;
      }

      await client
        .from("commercial_offer_sync_runs")
        .update(runPayload)
        .eq("id", runId);
    }

    return jsonResponse({
      success: status !== "FAILED",
      status,
      source_count: outcomes.length,
      success_count: successCount,
      failure_count: failureCount,
      verified_offer_count: verifiedOfferCount,
      review_offer_count: reviewOfferCount,
      candidate_count: candidateCount,
      discovered_url_count: discoveredUrlCount,
      catalog_version: sourceLoad.catalogV2 ? 2 : 1,
      sources: outcomes.map((item) => ({
        source_key: item.sourceKey,
        success: item.success,
        candidate_count: item.candidates,
        discovered_url_count: item.discoveredUrls,
        error_code: item.errorCode,
      })),
    }, status === "FAILED" ? 503 : 200);
  } catch (error) {
    const message = safeError(error).slice(0, 1500);

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
