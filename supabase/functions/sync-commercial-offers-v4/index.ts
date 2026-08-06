import { createClient } from "npm:@supabase/supabase-js@2";
import { detectBrand, extractOffersFromHtml, normalizeToken, type ExtractedOffer, type OfferSource } from "./extractor.ts";

type AnyRow = Record<string, unknown>;

type RunResult = {
  runId: string | null;
  sourcesTotal: number;
  sourcesProcessed: number;
  pagesOk: number;
  pagesFailed: number;
  candidatesFound: number;
  offersPublished: number;
  fallbacksPublished: number;
  brandsCovered: number;
  errors: string[];
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
if (!SUPABASE_URL || !SERVICE_ROLE_KEY) throw new Error("Supabase environment is incomplete.");
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json; charset=utf-8",
};

function stringValue(row: AnyRow, keys: string[]): string {
  for (const key of keys) {
    const value = row[key];
    if (typeof value === "string" && value.trim()) return value.trim();
    if (typeof value === "number" && Number.isFinite(value)) return String(value);
  }
  return "";
}

function booleanValue(row: AnyRow, keys: string[], fallback = true): boolean {
  for (const key of keys) {
    const value = row[key];
    if (typeof value === "boolean") return value;
  }
  return fallback;
}

function mapSource(row: AnyRow): OfferSource | null {
  const id = stringValue(row, ["id"]);
  const sourceKey = stringValue(row, ["source_key", "key", "slug", "id"]);
  const url = stringValue(row, ["official_url", "url", "source_url", "entry_url", "page_url"]);
  const brandField = stringValue(row, ["brand", "brand_slug", "make", "manufacturer"]);
  const brand = detectBrand(`${brandField} ${sourceKey} ${url}`);
  const active = booleanValue(row, ["is_active", "active", "enabled"], true);
  if (!id || !sourceKey || !url || !brand || !active || !/^https?:\/\//i.test(url)) return null;
  const official = /(^|\.)[a-z0-9-]+\.fr\//i.test(url) || !/dealabs|facebook|instagram|leboncoin/i.test(url);
  return { id, sourceKey, url, brand, official };
}

async function loadSources(): Promise<OfferSource[]> {
  const { data, error } = await supabase.from("commercial_offer_sources").select("*").limit(1000);
  if (error) throw new Error(`Unable to read commercial_offer_sources: ${error.message}`);
  const mapped = (data ?? []).map((row: unknown) => mapSource(row as AnyRow)).filter((row: OfferSource | null): row is OfferSource => row !== null);
  const unique = new Map<string, OfferSource>();
  for (const source of mapped) if (!unique.has(source.sourceKey)) unique.set(source.sourceKey, source);
  return [...unique.values()];
}

async function loadHealth(): Promise<Map<string, AnyRow>> {
  const { data, error } = await supabase.from("commercial_offer_v4_source_health").select("*").limit(2000);
  if (error) throw new Error(`Unable to read V4 source health: ${error.message}`);
  return new Map((data ?? []).map((row: unknown) => [String((row as AnyRow).source_key ?? ""), row as AnyRow] as [string, AnyRow]));
}

function dueSources(sources: OfferSource[], health: Map<string, AnyRow>, limit: number): OfferSource[] {
  const now = Date.now();
  return [...sources]
    .sort((a, b) => {
      const ha = health.get(a.sourceKey);
      const hb = health.get(b.sourceKey);
      const ta = Date.parse(String(ha?.last_success_at ?? ha?.last_attempt_at ?? "1970-01-01"));
      const tb = Date.parse(String(hb?.last_success_at ?? hb?.last_attempt_at ?? "1970-01-01"));
      const fa = Number(ha?.consecutive_failures ?? 0);
      const fb = Number(hb?.consecutive_failures ?? 0);
      const retryA = Date.parse(String(ha?.next_retry_at ?? "1970-01-01"));
      const retryB = Date.parse(String(hb?.next_retry_at ?? "1970-01-01"));
      const blockedA = retryA > now ? 1 : 0;
      const blockedB = retryB > now ? 1 : 0;
      return blockedA - blockedB || fa - fb || ta - tb;
    })
    .filter((source) => Date.parse(String(health.get(source.sourceKey)?.next_retry_at ?? "1970-01-01")) <= now)
    .slice(0, Math.max(1, Math.min(limit, 12)));
}

async function fetchPage(source: OfferSource): Promise<{ html: string; status: number; hash: string }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(source.url, {
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "user-agent": "Mozilla/5.0 (compatible; AutoClairOffers/4.0; +https://autoclair.app)",
        "accept-language": "fr-FR,fr;q=0.9,en;q=0.5",
        accept: "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.5",
      },
    });
    const html = (await response.text()).slice(0, 1_800_000);
    const bytes = new TextEncoder().encode(html);
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    const hash = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    if (html.length < 200) throw new Error("Page content is too short.");
    return { html, status: response.status, hash };
  } finally {
    clearTimeout(timer);
  }
}

async function updateHealth(source: OfferSource, values: AnyRow): Promise<void> {
  const payload = {
    source_key: source.sourceKey,
    official_url: source.url,
    brand: source.brand,
    updated_at: new Date().toISOString(),
    ...values,
  };
  const { error } = await supabase.from("commercial_offer_v4_source_health").upsert(payload, { onConflict: "source_key" });
  if (error) throw new Error(`Unable to update source health: ${error.message}`);
}

async function storeCandidate(source: OfferSource, offer: ExtractedOffer, contentHash: string): Promise<void> {
  const payload = {
    source_key: source.sourceKey,
    official_url: source.url,
    brand: source.brand,
    offer_key: offer.offerKey,
    title: offer.title,
    summary: offer.summary,
    category: offer.category,
    benefit_kind: offer.benefitKind,
    benefit_label: offer.benefitLabel,
    benefit_value: offer.benefitValue,
    price_amount: offer.priceAmount,
    starts_at: offer.startsAt,
    ends_at: offer.endsAt,
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
    conditions_summary: offer.conditionsSummary,
    eligibility_notes: offer.eligibilityNotes,
    requires_existing_contract: offer.requiresExistingContract,
    requires_network_participation: offer.requiresNetworkParticipation,
    requires_manual_eligibility: offer.requiresManualEligibility,
    validation_markers: offer.validationMarkers,
    confidence: offer.confidence,
    state: offer.confidence >= 0.62 ? "PUBLISHABLE" : "TO_CHECK",
    raw_excerpt: offer.rawExcerpt,
    content_hash: contentHash,
    last_seen_at: new Date().toISOString(),
  };
  const { error } = await supabase.from("commercial_offer_v4_candidates").upsert(payload, { onConflict: "source_key,offer_key" });
  if (error) throw new Error(`Unable to store V4 candidate: ${error.message}`);
}

async function findExistingOffer(offerKey: string): Promise<string | null> {
  const { data, error } = await supabase.from("commercial_offers").select("id").eq("offer_key", offerKey).limit(1);
  if (error) throw new Error(`Unable to lookup commercial offer: ${error.message}`);
  return data && data.length > 0 ? String(data[0].id) : null;
}

async function publishOffer(source: OfferSource, offer: ExtractedOffer, isFallback: boolean): Promise<string> {
  const now = new Date().toISOString();
  const payload: AnyRow = {
    source_id: source.id,
    offer_key: offer.offerKey,
    title: offer.title,
    summary: offer.summary,
    category: offer.category,
    benefit_kind: offer.benefitKind,
    benefit_label: offer.benefitLabel,
    benefit_value: offer.benefitValue,
    price_amount: offer.priceAmount,
    original_price_amount: null,
    currency: "EUR",
    starts_at: offer.startsAt,
    ends_at: offer.endsAt,
    status: "ACTIVE",
    official_url: source.url,
    brands: [source.brand],
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
    schedule_keywords: [],
    conditions_summary: offer.conditionsSummary,
    eligibility_notes: offer.eligibilityNotes,
    requires_existing_contract: offer.requiresExistingContract,
    requires_network_participation: offer.requiresNetworkParticipation,
    requires_manual_eligibility: true,
    validation_markers: offer.validationMarkers,
    is_featured: !isFallback && offer.confidence >= 0.82,
    match_level: isFallback ? "TO_CHECK" : offer.confidence >= 0.82 ? "CONFIRMED" : "LIKELY",
    match_confidence: offer.confidence,
    is_brand_fallback: isFallback,
    last_verified_at: now,
    v4_source_key: source.sourceKey,
    updated_at: now,
  };

  const existingId = await findExistingOffer(offer.offerKey);
  if (existingId) {
    const { error } = await supabase.from("commercial_offers").update(payload).eq("id", existingId);
    if (error) throw new Error(`Unable to update commercial offer: ${error.message}`);
    return existingId;
  }
  const { data, error } = await supabase.from("commercial_offers").insert(payload).select("id").single();
  if (error) throw new Error(`Unable to insert commercial offer: ${error.message}`);
  return String(data.id);
}

function fallbackOffer(source: OfferSource): ExtractedOffer {
  const brandLabel = source.brand.split(' ').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
  return {
    offerKey: `v4_brand_portal_${normalizeToken(source.brand).replace(/[^a-z0-9]+/g, '_')}`,
    title: source.official ? `Offres officielles ${brandLabel}` : `Offres recensées ${brandLabel}`,
    summary: source.official
      ? `Consultez les promotions et services actuellement publiés par ${brandLabel}. AutoClair continue l’analyse détaillée de cette source officielle.`
      : `Consultez les promotions et services recensés pour ${brandLabel}. La source et les conditions doivent être confirmées.`,
    category: "MAINTENANCE",
    benefitKind: "FIXED_PRICE",
    benefitLabel: "Conditions sur le site officiel",
    benefitValue: null,
    priceAmount: null,
    startsAt: null,
    endsAt: null,
    modelPatterns: [],
    excludedModelPatterns: [],
    fuelTypes: [],
    excludedFuelTypes: [],
    yearMin: null,
    yearMax: null,
    ageMin: null,
    ageMax: null,
    mileageMin: null,
    mileageMax: null,
    conditionsSummary: "Offre générale de repli. Les conditions exactes doivent être consultées sur la page officielle.",
    eligibilityNotes: "Compatible avec tous les modèles de la marque tant qu’aucune exclusion explicite n’est connue.",
    requiresExistingContract: false,
    requiresNetworkParticipation: true,
    requiresManualEligibility: true,
    validationMarkers: ["source officielle", "compatibilité marque", "conditions à confirmer"],
    confidence: 0.55,
    rawExcerpt: "Brand official offers portal fallback.",
  };
}

function sourcePriority(source: OfferSource): number {
  const normalizedUrl = normalizeToken(source.url);
  let score = source.official ? 100 : 0;
  if (/offre|promotion|service|entretien|apres vente|atelier/.test(normalizedUrl)) score += 40;
  if (/accueil|home|contact|mentions legales/.test(normalizedUrl)) score -= 20;
  return score;
}

async function ensureBrandFallbacks(sources: OfferSource[]): Promise<{ published: number; brands: number }> {
  const firstByBrand = new Map<string, OfferSource>();
  for (const source of sources) {
    const current = firstByBrand.get(source.brand);
    if (!current || sourcePriority(source) > sourcePriority(current)) firstByBrand.set(source.brand, source);
  }
  let published = 0;
  for (const source of firstByBrand.values()) {
    const fallback = fallbackOffer(source);
    const existingId = await findExistingOffer(fallback.offerKey);
    await publishOffer(source, fallback, true);
    if (!existingId) published++;
  }
  return { published, brands: firstByBrand.size };
}

async function expireStaleSourceOffers(source: OfferSource): Promise<void> {
  const cutoff = new Date(Date.now() - 14 * 24 * 3600000).toISOString();
  const { error } = await supabase.from("commercial_offers")
    .update({ status: "EXPIRED", updated_at: new Date().toISOString() })
    .eq("v4_source_key", source.sourceKey)
    .eq("is_brand_fallback", false)
    .eq("status", "ACTIVE")
    .lt("last_verified_at", cutoff);
  if (error) throw new Error(`Unable to expire stale offers: ${error.message}`);
}

async function processSource(source: OfferSource): Promise<{ ok: boolean; candidates: number; published: number; error?: string }> {
  try {
    const page = await fetchPage(source);
    const offers = extractOffersFromHtml(page.html, source);
    let published = 0;
    for (const offer of offers) {
      await storeCandidate(source, offer, page.hash);
      if (offer.confidence >= 0.62) {
        const id = await publishOffer(source, offer, false);
        const { error } = await supabase.from("commercial_offer_v4_candidates")
          .update({ state: "PUBLISHED", published_offer_id: id, last_seen_at: new Date().toISOString() })
          .eq("source_key", source.sourceKey).eq("offer_key", offer.offerKey);
        if (error) throw new Error(`Unable to mark candidate as published: ${error.message}`);
        published++;
      }
    }
    await expireStaleSourceOffers(source);
    await updateHealth(source, {
      last_attempt_at: new Date().toISOString(), last_success_at: new Date().toISOString(), last_http_status: page.status,
      consecutive_failures: 0, last_error: null, last_content_hash: page.hash,
      discovered_offer_count: offers.length, published_offer_count: published, next_retry_at: null,
    });
    return { ok: true, candidates: offers.length, published };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const { data } = await supabase.from("commercial_offer_v4_source_health")
      .select("consecutive_failures").eq("source_key", source.sourceKey).limit(1);
    const failures = Number(data?.[0]?.consecutive_failures ?? 0) + 1;
    const retryHours = Math.min(72, Math.max(1, 2 ** Math.min(failures, 6)));
    await updateHealth(source, {
      last_attempt_at: new Date().toISOString(), consecutive_failures: failures, last_error: message,
      next_retry_at: new Date(Date.now() + retryHours * 3600000).toISOString(),
    });
    return { ok: false, candidates: 0, published: 0, error: `${source.sourceKey}: ${message}` };
  }
}

async function execute(request: Request): Promise<RunResult> {
  let body: AnyRow = {};
  try { if (request.method !== "GET") body = await request.json(); } catch { body = {}; }
  const mode = String(body.mode ?? new URL(request.url).searchParams.get("mode") ?? "scheduled");
  const requestedLimit = Number(body.limit ?? new URL(request.url).searchParams.get("limit") ?? (mode === "bootstrap" ? 12 : 6));
  const result: RunResult = {
    runId: null, sourcesTotal: 0, sourcesProcessed: 0, pagesOk: 0, pagesFailed: 0,
    candidatesFound: 0, offersPublished: 0, fallbacksPublished: 0, brandsCovered: 0, errors: [],
  };
  const { data: run, error: runError } = await supabase.from("commercial_offer_v4_runs")
    .insert({ status: "RUNNING", mode, started_at: new Date().toISOString() }).select("id").single();
  if (!runError) result.runId = String(run.id);

  try {
    const sources = await loadSources();
    result.sourcesTotal = sources.length;
    if (sources.length === 0) throw new Error("No usable commercial offer sources were found.");
    const fallback = await ensureBrandFallbacks(sources);
    result.fallbacksPublished = fallback.published;
    result.brandsCovered = fallback.brands;
    const health = await loadHealth();
    const selected = dueSources(sources, health, requestedLimit);
    const processed = await Promise.all(selected.map((source) => processSource(source)));
    result.sourcesProcessed = processed.length;
    for (const item of processed) {
      if (item.ok) result.pagesOk++; else result.pagesFailed++;
      result.candidatesFound += item.candidates;
      result.offersPublished += item.published;
      if (item.error) result.errors.push(item.error);
    }
    if (result.runId) await supabase.from("commercial_offer_v4_runs").update({
      status: result.pagesOk > 0 || result.brandsCovered > 0 ? "SUCCESS" : "FAILED",
      finished_at: new Date().toISOString(), sources_total: result.sourcesTotal,
      sources_processed: result.sourcesProcessed, pages_ok: result.pagesOk, pages_failed: result.pagesFailed,
      candidates_found: result.candidatesFound, offers_published: result.offersPublished,
      fallbacks_published: result.fallbacksPublished, brands_covered: result.brandsCovered,
      details: { errors: result.errors.slice(0, 20) },
    }).eq("id", result.runId);
    return result;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    result.errors.push(message);
    if (result.runId) await supabase.from("commercial_offer_v4_runs").update({
      status: "FAILED", finished_at: new Date().toISOString(), message,
      details: { errors: result.errors },
    }).eq("id", result.runId);
    throw error;
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const result = await execute(request);
    return new Response(JSON.stringify({ ok: true, ...result }), { status: 200, headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ ok: false, error: message }), { status: 500, headers: corsHeaders });
  }
});
