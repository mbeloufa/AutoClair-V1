export type SourcePurpose =
  | "CURRENT_VEHICLE"
  | "VEHICLE_PURCHASE"
  | "FINANCE_INSURANCE"
  | "REFERENCE_ONLY"
  | "DISCOVERY_ONLY"
  | "OTHER";

export type EndpointType =
  | "HOME_OR_CATALOG"
  | "OFFERS"
  | "AFTER_SALES"
  | "FINANCE"
  | "NEW_STOCK"
  | "USED_OR_STOCK"
  | "REFERENCE";

export type TrustTier =
  | "PRIMARY"
  | "PROFESSIONAL"
  | "COMMUNITY_OR_MARKETPLACE";

export type MonitoringMode =
  | "HTML_RULES"
  | "HTML_DISCOVERY"
  | "LINK_DISCOVERY_ONLY"
  | "ADAPTER_REQUIRED"
  | "REFERENCE_ONLY"
  | "DISABLED_BY_POLICY";

export type PublicationPolicy =
  | "VALIDATED_RULES_ONLY"
  | "AUTO_HIGH_CONFIDENCE"
  | "QUARANTINE_ONLY"
  | "REFERENCE_ONLY";

export type ExtractionSource = {
  sourceKey: string;
  sourceName: string;
  sourceUrl: string;
  canonicalBrandCode: string;
  sourcePurpose: SourcePurpose;
  sourceRole: "DISCOVERY_ONLY" | "OFFER_HUB" | "OFFER_DETAIL" | "REFERENCE_ONLY";
  endpointType: EndpointType;
  trustTier: TrustTier;
  monitoringMode: MonitoringMode;
  publicationPolicy: PublicationPolicy;
  autoPublishThreshold: number;
};

export type KnownVehicle = {
  brand: string;
  model: string;
};

export type DiscoveredLink = {
  url: string;
  title: string;
  score: number;
};

export type ExtractedOffer = {
  fingerprint: string;
  title: string;
  summary: string;
  category: string;
  offerContext: "CURRENT_VEHICLE" | "VEHICLE_PURCHASE" | "FINANCE_INSURANCE";
  targetingScope: "ALL_VEHICLES" | "BRAND" | "MODEL" | "UNKNOWN";
  targetingText: string;
  benefitKind:
    | "PERCENT"
    | "FIXED_PRICE"
    | "FROM_PRICE"
    | "REIMBURSEMENT"
    | "FREE_SERVICE"
    | "INFO";
  benefitLabel: string;
  benefitValue: number | null;
  priceAmount: number | null;
  originalPriceAmount: number | null;
  currency: string;
  startsAt: string | null;
  endsAt: string | null;
  brands: string[];
  modelPatterns: string[];
  excludedModelPatterns: string[];
  fuelTypes: string[];
  excludedFuelTypes: string[];
  yearMin: number | null;
  yearMax: number | null;
  ageMin: number | null;
  ageMax: number | null;
  mileageMin: number | null;
  mileageMax: number | null;
  scheduleKeywords: string[];
  conditionsSummary: string;
  eligibilityNotes: string;
  requiresExistingContract: boolean;
  requiresNetworkParticipation: boolean;
  requiresManualEligibility: boolean;
  validationMarkers: string[];
  officialUrl: string;
  extractionMethod: string;
  confidence: number;
  rejectionReasons: string[];
  evidence: Record<string, unknown>;
  publishable: boolean;
};

type RawCandidate = {
  title: string;
  text: string;
  url: string;
  method: "JSON_LD" | "EMBEDDED_JSON" | "HTML_CARD" | "META";
  structured: Record<string, unknown>;
};

type Benefit = {
  kind: ExtractedOffer["benefitKind"];
  label: string;
  benefitValue: number | null;
  priceAmount: number | null;
  originalPriceAmount: number | null;
  explicit: boolean;
  evidenceText: string;
  monthly: boolean;
};

const MONTHS: Record<string, number> = {
  janvier: 1,
  fevrier: 2,
  mars: 3,
  avril: 4,
  mai: 5,
  juin: 6,
  juillet: 7,
  aout: 8,
  septembre: 9,
  octobre: 10,
  novembre: 11,
  decembre: 12,
};

const HTML_ENTITIES: Record<string, string> = {
  amp: "&",
  apos: "'",
  quot: '"',
  lt: "<",
  gt: ">",
  nbsp: " ",
  euro: "€",
  copy: "©",
  reg: "®",
  laquo: "«",
  raquo: "»",
  ndash: "–",
  mdash: "—",
  hellip: "…",
  rsquo: "’",
  lsquo: "‘",
  ldquo: "“",
  rdquo: "”",
  agrave: "à",
  acirc: "â",
  auml: "ä",
  ccedil: "ç",
  eacute: "é",
  egrave: "è",
  ecirc: "ê",
  euml: "ë",
  icirc: "î",
  iuml: "ï",
  ocirc: "ô",
  ouml: "ö",
  ugrave: "ù",
  ucirc: "û",
  uuml: "ü",
  Agrave: "À",
  Eacute: "É",
  Ccedil: "Ç",
};

const INVALID_TITLE_PATTERN = new RegExp(
  "^(?:" + [
    "choisir",
    "d[eé]couvrir",
    "en\\s+savoir\\s+plus",
    "voir\\s+l.?offre",
    "profiter\\s+de\\s+l.?offre",
    "nos\\s+offres",
    "promotions?",
    "livraison",
    "newsletter",
    "inscrivez[- ]vous",
    "les\\s+actualit[eé]s(?:\\s+du\\s+r[eé]seau)?",
    "faq\\b",
    "mod[eè]le\\s+pr[eé]sent[eé]",
    "trouvez\\s+votre\\s+v[eé]hicule",
    "liste\\s+des\\s+v[eé]hicules",
    "apr[eè]s\\s+un\\s+premier\\s+loyer",
    "prix",
    "loyer",
    "[aà]\\s+partir\\s+de",
    "nos\\s+voitures",
    "mod[eè]les?",
    "d[eé]tail\\s+et\\s+informations",
    "avertissement",
    "d[eé]claration\\s+de\\s+protection",
    "la\\s+circulation\\s+des\\s+v[eé]hicules",
    "service\\s+apr[eè]s[- ]vente",
    "©",
  ].join("|") + ")\\b",
  "i",
);

const BAD_TITLE_CONTAINS = [
  "newsletter",
  "politique de confidentialité",
  "protection des données",
  "data act",
  "mentions légales",
  "cookies",
  "copyright",
];

const COMMERCIAL_PATTERN = /\b(offre|promotion|promo|remise|r[eé]duction|[eé]conomisez|avantage|forfait|pack|gratuit|offert|rembours|[aà]\s+partir\s+de|mensualit[eé]|loyer|prime|franchise|cagnotte)\b/i;
const VEHICLE_SERVICE_PATTERN = /\b(entretien|r[eé]vision|vidange|pneu|pneumatique|frein|batterie|climatisation|contr[oô]le\s+technique|pare[- ]brise|carrosserie|accessoire|barres?\s+de\s+toit|pi[eè]ce|diagnostic|service|atelier)\b/i;

export function decodeHtmlEntities(value: string): string {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, hexadecimal: string) => {
      const parsed = Number.parseInt(hexadecimal, 16);
      return Number.isFinite(parsed) ? String.fromCodePoint(parsed) : _;
    })
    .replace(/&#([0-9]+);/g, (_, decimal: string) => {
      const parsed = Number.parseInt(decimal, 10);
      return Number.isFinite(parsed) ? String.fromCodePoint(parsed) : _;
    })
    .replace(/&([a-z][a-z0-9]+);/gi, (entity, name: string) => {
      return HTML_ENTITIES[name] ?? HTML_ENTITIES[name.toLowerCase()] ?? entity;
    });
}

export function stripHtml(html: string): string {
  return decodeHtmlEntities(
    html
      .replace(/<!--[\s\S]*?-->/g, " ")
      .replace(/<(script|style|noscript|svg|template|iframe)\b[^>]*>[\s\S]*?<\/\1>/gi, " ")
      .replace(/<(br|hr)\b[^>]*>/gi, "\n")
      .replace(/<\/(p|li|div|section|article|h[1-6]|tr)>/gi, "\n")
      .replace(/<[^>]+>/g, " "),
  )
    .replace(/\r/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export function normalizeText(value: string): string {
  return decodeHtmlEntities(value)
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[’‘`´]/g, "'")
    .replace(/[^a-z0-9%€+./'-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function compactText(value: unknown, maximum = 900): string {
  if (typeof value !== "string") return "";
  return decodeHtmlEntities(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maximum);
}

function safeNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value !== "string") return null;

  const normalized = value
    .replace(/[\s\u00a0\u202f.'’]/g, "")
    .replace(",", ".")
    .replace(/[^\d.-]/g, "");

  if (!normalized) return null;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function formatAmount(value: number): string {
  return Number.isInteger(value)
    ? value.toString()
    : value.toFixed(2).replace(/0+$/, "").replace(/\.$/, "").replace(".", ",");
}

function safeUrl(raw: unknown, fallback: string): string {
  if (typeof raw !== "string" || !raw.trim()) return fallback;
  try {
    const url = new URL(raw, fallback);
    if (url.protocol !== "https:") return fallback;
    url.hash = "";
    return url.toString();
  } catch {
    return fallback;
  }
}

function objectValue(object: Record<string, unknown>, keys: string[]): unknown {
  for (const key of keys) {
    if (object[key] !== undefined && object[key] !== null) return object[key];
  }
  return null;
}

function typeNames(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  if (typeof value === "string") return [value];
  return [];
}

function objectLooksCommercial(object: Record<string, unknown>): boolean {
  const types = typeNames(object["@type"]).map((value) => value.toLowerCase());
  if (types.some((value) => ["offer", "aggregateoffer", "product", "service", "vehicle", "car"].includes(value))) {
    return true;
  }

  const keys = Object.keys(object).map((key) => key.toLowerCase());
  const hasPrice = keys.some((key) => [
    "price", "lowprice", "highprice", "saleprice", "monthlypayment", "monthlyprice",
    "discount", "discountvalue", "saving", "amount", "loyer", "mensualite",
  ].includes(key));
  const hasName = keys.some((key) => ["name", "title", "headline", "label", "description"].includes(key));
  return hasPrice && hasName;
}

function flattenCommercialObjects(
  value: unknown,
  output: Array<Record<string, unknown>>,
  depth = 0,
  state = { visited: 0 },
): void {
  if (depth > 10 || state.visited > 5000) return;
  state.visited += 1;

  if (Array.isArray(value)) {
    for (const item of value.slice(0, 500)) flattenCommercialObjects(item, output, depth + 1, state);
    return;
  }
  if (!value || typeof value !== "object") return;

  const object = value as Record<string, unknown>;
  if (objectLooksCommercial(object)) output.push(object);

  for (const [key, child] of Object.entries(object)) {
    if (["image", "images", "picture", "pictures", "icon", "icons", "tracking", "analytics", "translations"].includes(key.toLowerCase())) {
      continue;
    }
    flattenCommercialObjects(child, output, depth + 1, state);
  }
}

function rawCandidateFromObject(
  object: Record<string, unknown>,
  pageUrl: string,
  method: RawCandidate["method"],
): RawCandidate | null {
  const nestedOffer = objectValue(object, ["offers", "offer"]);
  const nested = Array.isArray(nestedOffer)
    ? nestedOffer.find((item) => item && typeof item === "object")
    : nestedOffer && typeof nestedOffer === "object"
    ? nestedOffer
    : null;
  const merged = nested ? { ...object, ...(nested as Record<string, unknown>) } : object;

  const title = compactText(objectValue(merged, ["name", "title", "headline", "label", "productName", "model"]), 180);
  const description = compactText(objectValue(merged, ["description", "summary", "subtitle", "shortDescription", "legalText", "terms", "conditions"]), 1200);
  const price = objectValue(merged, ["price", "lowPrice", "salePrice", "monthlyPayment", "monthlyPrice", "amount", "loyer", "mensualite"]);
  const discount = objectValue(merged, ["discount", "discountValue", "saving", "remise", "reduction"]);
  const validThrough = objectValue(merged, ["priceValidUntil", "validThrough", "endDate", "endsAt", "dateFin"]);
  const startDate = objectValue(merged, ["validFrom", "startDate", "startsAt", "dateDebut"]);
  const currency = compactText(objectValue(merged, ["priceCurrency", "currency", "devise"]), 8);
  const url = safeUrl(objectValue(merged, ["url", "offerUrl", "link"]), pageUrl);

  const text = [title, description, price, discount, validThrough, startDate, currency]
    .filter((value) => value !== null && value !== undefined && String(value).trim())
    .map(String)
    .join(" · ");

  if (!title || !COMMERCIAL_PATTERN.test(normalizeText(text))) return null;
  return { title, text, url, method, structured: merged };
}

function extractJsonCandidates(html: string, pageUrl: string): RawCandidate[] {
  const candidates: RawCandidate[] = [];
  const scriptPattern = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let totalJsonBytes = 0;

  for (const match of html.matchAll(scriptPattern)) {
    const attributes = match[1] ?? "";
    const body = (match[2] ?? "").trim();
    if (!body || body.length > 600000) continue;

    const isJsonLd = /type\s*=\s*["']application\/ld\+json["']/i.test(attributes);
    const isEmbeddedJson = /type\s*=\s*["']application\/json["']/i.test(attributes) ||
      /id\s*=\s*["'](__NEXT_DATA__|__NUXT_DATA__|__APOLLO_STATE__)["']/i.test(attributes);
    if (!isJsonLd && !isEmbeddedJson) continue;

    totalJsonBytes += body.length;
    if (totalJsonBytes > 1200000) break;

    let parsed: unknown;
    try {
      parsed = JSON.parse(body.replace(/^\s*<!--/, "").replace(/-->\s*$/, ""));
    } catch {
      continue;
    }

    const objects: Array<Record<string, unknown>> = [];
    flattenCommercialObjects(parsed, objects);
    for (const object of objects.slice(0, 250)) {
      const candidate = rawCandidateFromObject(object, pageUrl, isJsonLd ? "JSON_LD" : "EMBEDDED_JSON");
      if (candidate) candidates.push(candidate);
    }
  }
  return candidates;
}

function firstHeading(blockHtml: string): string {
  const heading = blockHtml.match(/<(h[1-6]|strong|b)\b[^>]*>([\s\S]*?)<\/\1>/i);
  if (heading) return compactText(stripHtml(heading[2] ?? ""), 180);

  const plain = stripHtml(blockHtml);
  return plain
    .split(/(?<=[.!?])\s+|\n+/)
    .map((part) => part.trim())
    .find((part) => part.length >= 8 && part.length <= 180) ?? "";
}

function titleIsInvalid(title: string): boolean {
  const compact = compactText(title, 180);
  const normalized = normalizeText(compact);
  if (compact.length < 8 || compact.length > 180) return true;
  if (INVALID_TITLE_PATTERN.test(compact)) return true;
  if (BAD_TITLE_CONTAINS.some((bad) => normalized.includes(normalizeText(bad)))) return true;
  if (/^[\d\s.,€%+*/()-]+$/.test(compact)) return true;
  const letters = compact.match(/[A-Za-zÀ-ÖØ-öø-ÿ]/g)?.length ?? 0;
  return letters < 6;
}

function sentenceCandidates(text: string): string[] {
  return decodeHtmlEntities(text)
    .split(/(?<=[.!?;])\s+|\n+/)
    .map((value) => value.replace(/\s+/g, " ").trim())
    .filter((value) => value.length >= 12 && value.length <= 220);
}

function bestOfferSentence(text: string): string {
  const sentences = sentenceCandidates(text);
  let best = "";
  let bestScore = -1000;

  for (const sentence of sentences) {
    if (titleIsInvalid(sentence)) continue;
    const normalized = normalizeText(sentence);
    let score = 0;
    if (COMMERCIAL_PATTERN.test(normalized)) score += 3;
    if (VEHICLE_SERVICE_PATTERN.test(normalized)) score += 3;
    if (/\d\s*%|\d[\d\s.,]*\s*€|gratuit|offert|rembours|remise|réduction/i.test(sentence)) score += 4;
    if (/^(offre|promotion|promo)\b/i.test(sentence)) score += 1;
    if (score > bestScore) {
      bestScore = score;
      best = sentence;
    }
  }
  return bestScore >= 6 ? best : "";
}

function extractHtmlCandidates(html: string, pageUrl: string): RawCandidate[] {
  const candidates: RawCandidate[] = [];
  const patterns = [
    /<(article|section|li|aside)\b[^>]*>([\s\S]*?)<\/\1>/gi,
    /<div\b[^>]*(?:class|id)\s*=\s*["'][^"']*(?:offer|offre|promo|deal|campaign|card|teaser)[^"']*["'][^>]*>([\s\S]*?)<\/div>/gi,
    /<(h[1-4])\b[^>]*>([\s\S]*?)<\/\1>([\s\S]{0,1200}?)(?=<h[1-4]\b|$)/gi,
  ];

  for (const pattern of patterns) {
    let seen = 0;
    for (const match of html.matchAll(pattern)) {
      if (seen >= 400) break;
      seen += 1;

      const blockHtml = match[0];
      const plain = stripHtml(blockHtml).replace(/\s+/g, " ").trim();
      if (plain.length < 35 || plain.length > 1800) continue;

      const normalized = normalizeText(plain);
      if (!COMMERCIAL_PATTERN.test(normalized)) continue;
      if (!/\d\s*%|\d[\d\s.,]*\s*€|gratuit|offert|rembours|remise|réduction|cagnotte/i.test(plain)) continue;

      let title = firstHeading(blockHtml);
      if (titleIsInvalid(title)) title = bestOfferSentence(plain);
      if (!title || titleIsInvalid(title)) continue;

      // Keep evidence local to the offer card. Large legal/footer blocks are a major source of false positives.
      const titleIndex = plain.toLowerCase().indexOf(title.toLowerCase());
      let localText = plain;
      if (titleIndex >= 0 && plain.length > 1000) {
        localText = plain.slice(Math.max(0, titleIndex - 100), Math.min(plain.length, titleIndex + 900));
      } else {
        localText = plain.slice(0, 1100);
      }

      candidates.push({ title, text: localText, url: pageUrl, method: "HTML_CARD", structured: {} });
    }
  }
  return candidates;
}

function metaContent(html: string, names: string[]): string {
  for (const name of names) {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const patterns = [
      new RegExp(`<meta\\b[^>]*(?:property|name)\\s*=\\s*["']${escaped}["'][^>]*content\\s*=\\s*["']([^"']+)["'][^>]*>`, "i"),
      new RegExp(`<meta\\b[^>]*content\\s*=\\s*["']([^"']+)["'][^>]*(?:property|name)\\s*=\\s*["']${escaped}["'][^>]*>`, "i"),
    ];
    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match?.[1]) return compactText(match[1], 700);
    }
  }
  return "";
}

function extractMetaCandidate(html: string, pageUrl: string): RawCandidate[] {
  const title = metaContent(html, ["og:title", "twitter:title"]) || compactText(html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? "", 180);
  const description = metaContent(html, ["og:description", "description", "twitter:description"]);
  const price = metaContent(html, ["product:price:amount", "og:price:amount", "product:sale_price:amount"]);
  const currency = metaContent(html, ["product:price:currency", "og:price:currency"]);
  const text = [title, description, price, currency].filter(Boolean).join(" · ");
  if (!title || titleIsInvalid(title) || !COMMERCIAL_PATTERN.test(normalizeText(text))) return [];
  return [{ title, text, url: pageUrl, method: "META", structured: { price, currency } }];
}

function deduplicateRawCandidates(candidates: RawCandidate[]): RawCandidate[] {
  const deduplicated = new Map<string, RawCandidate>();
  const rank = (method: RawCandidate["method"]): number => method === "JSON_LD" ? 4 : method === "EMBEDDED_JSON" ? 3 : method === "HTML_CARD" ? 2 : 1;

  for (const candidate of candidates) {
    const key = normalizeText(`${candidate.title} ${candidate.text.slice(0, 250)}`).slice(0, 420);
    if (!key) continue;
    const existing = deduplicated.get(key);
    if (!existing || rank(candidate.method) > rank(existing.method)) deduplicated.set(key, candidate);
  }
  return Array.from(deduplicated.values()).slice(0, 120);
}

function parseMoneyValue(raw: string, decimals?: string): number | null {
  const compact = raw.replace(/[\s\u00a0\u202f.'’]/g, "") + (decimals ? `.${decimals}` : "");
  const value = Number(compact.replace(",", "."));
  return Number.isFinite(value) && value > 0 && value <= 500000 ? value : null;
}

export function parsePrice(text: string): {
  price: number | null;
  original: number | null;
  monthly: boolean;
  from: boolean;
} {
  const decoded = decodeHtmlEntities(text).replace(/[’']/g, "'");
  const lowered = decoded.toLowerCase();
  const money = /(\d{1,3}(?:[ \u00a0\u202f.'’]\d{3})+|\d{1,6})(?:[,.](\d{1,2}))?\s*(?:€|eur\b)/gi;

  let catalog: number | null = null;
  let sale: number | null = null;
  let monthlyAmount: number | null = null;
  let neutral: number | null = null;
  let from = false;

  for (const match of decoded.matchAll(money)) {
    const amount = parseMoneyValue(match[1], match[2]);
    if (amount === null) continue;
    const index = match.index ?? 0;
    const before = lowered.slice(Math.max(0, index - 100), index);
    const after = lowered.slice(index, Math.min(lowered.length, index + 70));
    const afterAmount = lowered.slice(index + match[0].length, Math.min(lowered.length, index + match[0].length + 70));

    const marker = (patterns: RegExp[]): number => {
      let best = -1;
      for (const pattern of patterns) {
        for (const m of before.matchAll(pattern)) best = Math.max(best, m.index ?? -1);
      }
      return best;
    };

    const catalogPos = marker([/prix\s+catalogue/g, /prix\s+initial/g, /ancien\s+prix/g, /au\s+lieu\s+de/g, /tarif\s+catalogue/g]);
    const salePos = marker([/prix\s+[a-z0-9-]{2,24}\s+store/g, /prix\s+propos[eé]/g, /prix\s+promo(?:tionnel)?/g, /forfait(?:\s+à|\s+a)?/g, /[aà]\s+partir\s+de/g]);
    const firstRentPos = marker([/premier\s+loyer(?:\s+de)?/g, /1er\s+loyer(?:\s+de)?/g, /apport(?:\s+de)?/g]);
    const discountPos = marker([/remise(?:\s+de)?/g, /r[eé]duction(?:\s+de)?/g, /[eé]conomisez/g, /prime(?:\s+de)?/g, /rembours[eé]s?/g]);
    const nearest = Math.max(catalogPos, salePos, firstRentPos, discountPos);

    if (firstRentPos >= 0 && firstRentPos === nearest) continue;
    if (discountPos >= 0 && discountPos === nearest) continue;
    if (/^\s*(?:de\s+)?(?:remise|r[eé]duction|rembours[eé]s?|en\s+cagnotte)\b/i.test(afterAmount)) continue;

    if (/(\/\s*mois|par\s+mois|mensualit|mois\b)/i.test(after.slice(0, 55))) {
      monthlyAmount ??= amount;
      continue;
    }
    if (salePos >= 0 && salePos > catalogPos) {
      sale ??= amount;
      from ||= /[aà]\s+partir\s+de/i.test(before.slice(Math.max(0, salePos)));
      continue;
    }
    if (catalogPos >= 0 && catalogPos > salePos) {
      catalog ??= amount;
      continue;
    }
    neutral ??= amount;
  }

  const chosen = sale ?? monthlyAmount ?? neutral;
  return { price: chosen, original: catalog, monthly: monthlyAmount !== null && chosen === monthlyAmount, from };
}

function explicitPercent(text: string): { value: number; evidence: string } | null {
  const patterns = [
    /(?:jusqu['’]?\s*[aà]\s*)?(-?\s*\d{1,2})\s*%\s+(?:de\s+)?(?:remise|r[eé]duction|rembours[eé]|offert)/i,
    /(?:remise|r[eé]duction)\s+(?:imm[eé]diate\s+)?(?:de\s+)?(\d{1,2})\s*%/i,
    /(?:jusqu['’]?\s*[aà]\s*)?-(\d{1,2})\s*%/i,
    /(\d{1,2})\s*%\s+du\s+(?:montage|prix)\s+offert/i,
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (!match) continue;
    const value = Math.abs(Number.parseInt(match[1].replace(/\s/g, ""), 10));
    if (value > 0 && value <= 90) return { value, evidence: match[0] };
  }
  return null;
}

function explicitFixedDiscount(text: string): { value: number; evidence: string } | null {
  const amount = "(\\d{1,3}(?:[ \u00a0\u202f.]\\d{3})+|\\d{1,4})(?:[,.](\\d{1,2}))?";
  const patterns = [
    new RegExp(`(?:jusqu['’]?\\s*[aà]\\s*)?${amount}\\s*€\\s+(?:de\\s+)?(?:remise|r[eé]duction|rembours[eé]s?|rembours[eé]e?|en\\s+cagnotte)`, "i"),
    new RegExp(`(?:remise|r[eé]duction|remboursement|prise\\s+en\\s+charge|prime)(?:\\s+imm[eé]diate)?\\s+(?:de\\s+|jusqu['’]?\\s*[aà]\\s*)?${amount}\\s*€`, "i"),
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (!match) continue;
    const raw = match[1];
    const decimals = match[2];
    const value = parseMoneyValue(raw, decimals);
    if (value !== null && value > 0 && value <= 5000) return { value, evidence: match[0] };
  }
  return null;
}

function benefitFromText(text: string, structured: Record<string, unknown>): Benefit {
  const normalized = normalizeText(text);
  const percent = explicitPercent(text);
  const fixedDiscount = explicitFixedDiscount(text);
  const parsedPrice = parsePrice(text);
  const structuredPrice = safeNumber(objectValue(structured, ["price", "lowPrice", "salePrice", "monthlyPayment", "monthlyPrice", "amount", "loyer", "mensualite"]));
  const structuredOriginal = safeNumber(objectValue(structured, ["highPrice", "originalPrice", "listPrice", "oldPrice", "prixCatalogue"]));
  const price = { ...parsedPrice, price: structuredPrice ?? parsedPrice.price, original: structuredOriginal ?? parsedPrice.original };

  if (percent) {
    return {
      kind: "PERCENT",
      label: `-${formatAmount(percent.value)} %`,
      benefitValue: percent.value,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
      evidenceText: percent.evidence,
      monthly: price.monthly,
    };
  }

  if (fixedDiscount) {
    const reimbursement = /rembours|prise\s+en\s+charge|cagnotte/i.test(fixedDiscount.evidence);
    return {
      kind: "REIMBURSEMENT",
      label: `${formatAmount(fixedDiscount.value)} € ${reimbursement ? "remboursés" : "de remise"}`,
      benefitValue: fixedDiscount.value,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
      evidenceText: fixedDiscount.evidence,
      monthly: price.monthly,
    };
  }

  const freeMatch = text.match(/\b([A-Za-zÀ-ÖØ-öø-ÿ][^.!?;]{0,90}?\b(?:gratuit|gratuite|offert|offerte|offerts|offertes))\b/i);
  if (freeMatch) {
    return {
      kind: "FREE_SERVICE",
      label: compactText(freeMatch[1], 120),
      benefitValue: null,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
      evidenceText: freeMatch[0],
      monthly: price.monthly,
    };
  }

  if (price.price !== null) {
    const perTyreUnit = /\b(?:pour|par)\s+(?:un\s+)?(?:pneu|pneumatique)\b/i.test(text);
    const suffix = price.monthly ? " / mois" : perTyreUnit ? " / pneu" : "";
    return {
      kind: price.from ? "FROM_PRICE" : "FIXED_PRICE",
      label: `${price.from ? "À partir de " : ""}${formatAmount(price.price)} €${suffix}`,
      benefitValue: null,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
      evidenceText: `${formatAmount(price.price)} €${suffix}`,
      monthly: price.monthly,
    };
  }

  if (/\b(remise|r[eé]duction|promotion|avantage|prime)\b/i.test(normalized)) {
    return {
      kind: "INFO",
      label: "Avantage commercial à confirmer",
      benefitValue: null,
      priceAmount: null,
      originalPriceAmount: null,
      explicit: false,
      evidenceText: "",
      monthly: false,
    };
  }

  return {
    kind: "INFO",
    label: "Conditions commerciales à consulter",
    benefitValue: null,
    priceAmount: null,
    originalPriceAmount: null,
    explicit: false,
    evidenceText: "",
    monthly: false,
  };
}

function isoDate(year: number, month: number, day: number): string | null {
  if (year < 2020 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) return null;
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return `${year.toString().padStart(4, "0")}-${month.toString().padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
}

function year4(raw: string): number {
  const value = Number.parseInt(raw, 10);
  return raw.length === 2 ? 2000 + value : value;
}

function frenchDate(dayRaw: string, monthRaw: string, yearRaw: string | undefined, fallbackYear: number): string | null {
  const month = MONTHS[normalizeText(monthRaw)];
  if (!month) return null;
  return isoDate(yearRaw ? year4(yearRaw) : fallbackYear, month, Number.parseInt(dayRaw, 10));
}

export function dateRangeFromTextForTest(text: string): { startsAt: string | null; endsAt: string | null } {
  return dateRangeFromText(text, {});
}

function dateRangeFromText(
  text: string,
  structured: Record<string, unknown>,
): { startsAt: string | null; endsAt: string | null } {
  const decoded = decodeHtmlEntities(text).replace(/1ᵉʳ|1er/gi, "1");
  const normalized = normalizeText(decoded);
  const currentYear = new Date().getUTCFullYear();

  const parseStructured = (value: unknown): string | null => {
    const compact = compactText(value, 30);
    const iso = compact.match(/\b(20\d{2})-(\d{2})-(\d{2})\b/);
    return iso ? isoDate(Number.parseInt(iso[1], 10), Number.parseInt(iso[2], 10), Number.parseInt(iso[3], 10)) : null;
  };

  let startsAt = parseStructured(objectValue(structured, ["validFrom", "startDate", "startsAt", "dateDebut"]));
  let endsAt = parseStructured(objectValue(structured, ["priceValidUntil", "validThrough", "endDate", "endsAt", "dateFin"]));

  // Numeric explicit range: 27/07/26 au 30/08/26 or 27/07/2026 - 30/08/2026.
  const numericRange = normalized.match(/\b(0?[1-9]|[12]\d|3[01])[\/.](0?[1-9]|1[0-2])[\/.](\d{2}|20\d{2})\s*(?:au|a|-|jusqu[' ]?au)\s*(0?[1-9]|[12]\d|3[01])[\/.](0?[1-9]|1[0-2])[\/.](\d{2}|20\d{2})\b/);
  if (numericRange) {
    startsAt ??= isoDate(year4(numericRange[3]), Number.parseInt(numericRange[2], 10), Number.parseInt(numericRange[1], 10));
    endsAt ??= isoDate(year4(numericRange[6]), Number.parseInt(numericRange[5], 10), Number.parseInt(numericRange[4], 10));
  }

  // French range where the year is often written only once at the end.
  const frenchRange = normalized.match(/\b(?:du\s+)?(0?[1-9]|[12]\d|3[01])\s+(janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre|octobre|novembre|decembre)(?:\s+(\d{2}|20\d{2}))?\s*(?:au|a|-|jusqu[' ]?au)\s*(0?[1-9]|[12]\d|3[01])\s+(janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre|octobre|novembre|decembre)(?:\s+(\d{2}|20\d{2}))?\b/);
  if (frenchRange) {
    const endYear = frenchRange[6] ? year4(frenchRange[6]) : currentYear;
    const startYear = frenchRange[3] ? year4(frenchRange[3]) : endYear;
    startsAt ??= frenchDate(frenchRange[1], frenchRange[2], String(startYear), startYear);
    endsAt ??= frenchDate(frenchRange[4], frenchRange[5], String(endYear), endYear);
  }

  // Explicit end only. This must NEVER become startsAt.
  if (!endsAt) {
    const untilFrench = normalized.match(/\b(?:valable\s+)?jusqu[' ]?au\s+(0?[1-9]|[12]\d|3[01])\s+(janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre|octobre|novembre|decembre)(?:\s+(\d{2}|20\d{2}))?\b/);
    if (untilFrench) endsAt = frenchDate(untilFrench[1], untilFrench[2], untilFrench[3], currentYear);
  }
  if (!endsAt) {
    const untilNumeric = normalized.match(/\b(?:valable\s+)?jusqu[' ]?au\s+(0?[1-9]|[12]\d|3[01])[\/.](0?[1-9]|1[0-2])[\/.](\d{2}|20\d{2})\b/);
    if (untilNumeric) endsAt = isoDate(year4(untilNumeric[3]), Number.parseInt(untilNumeric[2], 10), Number.parseInt(untilNumeric[1], 10));
  }

  // Common form: "valable du 1 janvier au 31 décembre 2026" is handled above.
  if (startsAt && endsAt && startsAt > endsAt) {
    const temporary = startsAt;
    startsAt = endsAt;
    endsAt = temporary;
  }
  return { startsAt, endsAt };
}

function integerFromPattern(normalized: string, pattern: RegExp): number | null {
  const match = normalized.match(pattern);
  const parsed = safeNumber(match?.[1]);
  return parsed === null ? null : Math.round(parsed);
}

function eligibilityFromText(text: string): {
  yearMin: number | null;
  yearMax: number | null;
  ageMin: number | null;
  ageMax: number | null;
  mileageMin: number | null;
  mileageMax: number | null;
  fuelTypes: string[];
  excludedFuelTypes: string[];
  requiresExistingContract: boolean;
  requiresManualEligibility: boolean;
} {
  const normalized = normalizeText(text);
  let ageMin: number | null = null;
  let ageMax: number | null = null;

  const betweenAge = normalized.match(/\b(?:entre|de)\s*(\d{1,2})\s*(?:et|a)\s*(\d{1,2})\s*ans\b/);
  if (betweenAge) {
    ageMin = Number.parseInt(betweenAge[1], 10);
    ageMax = Number.parseInt(betweenAge[2], 10);
  } else {
    const moreThan = integerFromPattern(normalized, /\b(?:plus de|age de plus de)\s*(\d{1,2})\s*ans\b/);
    const atLeast = integerFromPattern(normalized, /\b(?:au moins|minimum)\s*(\d{1,2})\s*ans\b/);
    const lessThan = integerFromPattern(normalized, /\b(?:moins de|age inferieur a)\s*(\d{1,2})\s*ans\b/);
    const atMost = integerFromPattern(normalized, /\b(?:maximum|au plus)\s*(\d{1,2})\s*ans\b/);
    if (moreThan !== null) ageMin = moreThan + 1;
    if (atLeast !== null) ageMin = atLeast;
    if (lessThan !== null) ageMax = Math.max(0, lessThan - 1);
    if (atMost !== null) ageMax = atMost;
  }

  const yearRange = normalized.match(/\b(?:de|entre|immatricule(?:e)?s? de)\s*(20\d{2})\s*(?:a|et|-)\s*(20\d{2})\b/);
  const compact = normalized.replace(/\s+/g, "");
  const mileageMax = integerFromPattern(compact, /\b(?:moinsde|maximum|jusqua|limitede)(\d{3,6})km\b/);
  const mileageMin = integerFromPattern(compact, /\b(?:plusde|minimum|apartirde)(\d{3,6})km\b/);

  const fuelTypes: string[] = [];
  const excludedFuelTypes: string[] = [];
  const fuelMap: Array<[string, RegExp]> = [
    ["electric", /\b(electrique|100 electrique|electric|ev)\b/],
    ["hybrid", /\b(hybride|hybrid|phev|plug in)\b/],
    ["lpg", /\b(gpl|lpg)\b/],
    ["diesel", /\b(diesel|gazole)\b/],
    ["petrol", /\b(essence|petrol|gasoline)\b/],
  ];

  for (const [fuel, pattern] of fuelMap) {
    for (const match of normalized.matchAll(new RegExp(pattern.source, "g"))) {
      const location = match.index ?? 0;
      const prefix = normalized.slice(Math.max(0, location - 45), location);
      if (/\b(hors|exclu|sauf|non compatible|a l exclusion)\b/.test(prefix)) excludedFuelTypes.push(fuel);
      else fuelTypes.push(fuel);
    }
  }

  return {
    yearMin: yearRange ? Number.parseInt(yearRange[1], 10) : null,
    yearMax: yearRange ? Number.parseInt(yearRange[2], 10) : null,
    ageMin,
    ageMax,
    mileageMin,
    mileageMax,
    fuelTypes: Array.from(new Set(fuelTypes.filter((f) => !excludedFuelTypes.includes(f)))),
    excludedFuelTypes: Array.from(new Set(excludedFuelTypes)),
    requiresExistingContract: /\b(contrat (?:d )?entretien (?:valide|en cours)|reserve aux titulaires d un contrat|souscription d un contrat)\b/.test(normalized),
    requiresManualEligibility: /\b(sous reserve|reservee? aux|valable|jusqu au|dans la limite|conditions|participant|eligibilite|hors|minimum|maximum|contrat|financement|reprise|selection de|dimension)\b/.test(normalized),
  };
}

function categoryFromText(text: string, source: ExtractionSource): string {
  const normalized = normalizeText(text);
  if (source.sourcePurpose === "VEHICLE_PURCHASE") {
    return source.endpointType === "USED_OR_STOCK" ? "USED_VEHICLE" : "NEW_VEHICLE";
  }

  const rules: Array<[string, RegExp]> = [
    ["INSPECTION", /\b(controle technique|contre visite)\b/],
    ["WINDSCREEN", /\b(pare brise|vitrage|bris de glace)\b/],
    ["TYRES", /\b(pneus?|pneumatiques?|jantes?|montage de pneus)\b/],
    ["BATTERY", /\b(batterie|demarrage)\b/],
    ["CLIMATE", /\b(climatisation|recharge clim|filtre habitacle)\b/],
    ["BODYWORK", /\b(carrosserie|peinture|rayure|debosselage)\b/],
    ["ACCESSORIES", /\b(accessoire|barres? de toit|coffre de toit|attelage)\b/],
    ["CONTRACT", /\b(contrat d entretien|contrat entretien|service care|flexcare)\b/],
    ["INSURANCE", /\b(assurance|protection financiere)\b/],
    ["ASSISTANCE", /\b(assistance|depannage|remorquage)\b/],
    ["FINANCE", /\b(financement|credit|loa|lld|leasing|loyer)\b/],
    ["PARTS", /\b(piece|pieces|filtre|plaquette|disque|essuie glace)\b/],
    ["MAINTENANCE", /\b(entretien|revision|vidange|frein|forfait|diagnostic)\b/],
  ];
  for (const [category, pattern] of rules) if (pattern.test(normalized)) return category;
  return "OTHER";
}

function scheduleKeywords(category: string, text: string): string[] {
  const normalized = normalizeText(text);
  const byCategory: Record<string, string[]> = {
    INSPECTION: ["controle technique", "contre visite"],
    WINDSCREEN: ["pare brise", "vitrage", "bris de glace"],
    TYRES: ["pneu", "pneumatique"],
    BATTERY: ["batterie"],
    CLIMATE: ["climatisation", "filtre habitacle"],
    BODYWORK: ["carrosserie", "peinture"],
    CONTRACT: ["entretien", "revision", "vidange"],
    PARTS: ["remplacement", "reparation"],
    ACCESSORIES: ["accessoire", "barres de toit"],
    MAINTENANCE: ["entretien", "revision", "vidange", "filtre", "frein", "distribution"],
  };
  return (byCategory[category] ?? []).filter((keyword) => normalized.includes(keyword));
}

function knownModelsInText(text: string, sourceBrand: string, knownVehicles: KnownVehicle[]): string[] {
  const normalized = ` ${normalizeText(text)} `;
  const matches = new Set<string>();
  for (const vehicle of knownVehicles) {
    if (sourceBrand !== "*" && vehicle.brand !== sourceBrand) continue;
    const model = normalizeText(vehicle.model);
    if (!model || model.length < 2) continue;
    if (normalized.includes(` ${model} `)) {
      matches.add(vehicle.model.trim());
      continue;
    }
    const tokens = model.split(/\s+/).filter((token) => token.length >= 2).filter((token) => !["model", "modele", "nouveau", "nouvelle"].includes(token));
    if (tokens.length >= 2 && tokens.every((token) => normalized.includes(` ${token} `))) matches.add(vehicle.model.trim());
  }
  return Array.from(matches).slice(0, 20);
}

function modelScope(text: string, source: ExtractionSource, models: string[]): ExtractedOffer["targetingScope"] {
  if (models.length > 0) return "MODEL";
  if (source.sourcePurpose === "VEHICLE_PURCHASE") return "UNKNOWN";
  if (source.canonicalBrandCode === "*") return "ALL_VEHICLES";
  const normalized = normalizeText(text);
  if (/\b(uniquement pour|compatible avec|reserve au modele|reserve aux modeles)\b/.test(normalized)) return "UNKNOWN";
  return "BRAND";
}

function conditionsFromText(text: string): string {
  const sentences = sentenceCandidates(text)
    .filter((value) => /\b(sous r[eé]serve|r[eé]serv[eé]e? aux|valable|jusqu['’]?au|dans la limite|conditions|participant|[eé]ligibilit[eé]|hors|minimum|maximum|contrat|financement|reprise|s[eé]lection|dimension)\b/i.test(value));
  return Array.from(new Set(sentences)).slice(0, 4).join(" ").slice(0, 900);
}

function distinctiveMarkers(title: string, benefit: Benefit, dates: { startsAt: string | null; endsAt: string | null }, text: string): string[] {
  const markers = new Set<string>();
  if (title.length >= 10) markers.add(title);
  if (benefit.evidenceText.length >= 5) markers.add(benefit.evidenceText);
  if (dates.endsAt) markers.add(dates.endsAt);
  const condition = sentenceCandidates(text).find((value) => /\b(valable|participant|hors|r[eé]serv[eé]|limite|condition)\b/i.test(value));
  if (condition) markers.add(condition);
  return Array.from(markers).slice(0, 5);
}

async function hashHex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function offerContext(source: ExtractionSource): ExtractedOffer["offerContext"] {
  if (source.sourcePurpose === "VEHICLE_PURCHASE") return "VEHICLE_PURCHASE";
  if (source.sourcePurpose === "FINANCE_INSURANCE") return "FINANCE_INSURANCE";
  return "CURRENT_VEHICLE";
}

function confidenceFor(
  candidate: RawCandidate,
  source: ExtractionSource,
  titleValid: boolean,
  benefit: Benefit,
  category: string,
  dates: { startsAt: string | null; endsAt: string | null },
  targetingScope: ExtractedOffer["targetingScope"],
  conditions: string,
): { confidence: number; reasons: string[] } {
  let score = source.trustTier === "PRIMARY" ? 20 : source.trustTier === "PROFESSIONAL" ? 15 : 3;
  const reasons: string[] = [];
  score += candidate.method === "JSON_LD" ? 20 : candidate.method === "EMBEDDED_JSON" ? 18 : candidate.method === "HTML_CARD" ? 15 : 5;
  if (titleValid) score += 10; else reasons.push("Titre non exploitable");
  if (benefit.explicit) score += 22; else reasons.push("Avantage non explicite");
  if (category !== "OTHER") score += 12; else reasons.push("Catégorie non déterminée");
  if (dates.startsAt || dates.endsAt) score += 8;
  if (targetingScope !== "UNKNOWN") score += 8; else reasons.push("Ciblage ambigu");
  if (conditions) score += 4;
  if (candidate.text.length > 1300) { score -= 8; reasons.push("Bloc trop large"); }
  return { confidence: Math.max(0, Math.min(100, Math.round(score))), reasons };
}

function deterministicPublishable(
  candidate: RawCandidate,
  source: ExtractionSource,
  titleValid: boolean,
  benefit: Benefit,
  category: string,
  context: ExtractedOffer["offerContext"],
  targetingScope: ExtractedOffer["targetingScope"],
  confidence: number,
  endsAt: string | null,
  models: string[],
): boolean {
  if (source.publicationPolicy !== "AUTO_HIGH_CONFIDENCE") return false;
  if (!["OFFER_HUB", "OFFER_DETAIL"].includes(source.sourceRole)) return false;
  if (source.trustTier === "COMMUNITY_OR_MARKETPLACE") return false;
  if (candidate.method === "META") return false;
  if (!titleValid || !benefit.explicit || category === "OTHER" || targetingScope === "UNKNOWN") return false;
  if (endsAt && new Date(`${endsAt}T23:59:59Z`).getTime() < Date.now()) return false;
  if (context === "VEHICLE_PURCHASE" && models.length === 0) return false;

  // V5 required 95 for everything, while a clean professional HTML card could mathematically peak below 95.
  // V6 uses hard semantic gates first, then a realistic quality floor.
  const floor = context === "VEHICLE_PURCHASE"
    ? (source.trustTier === "PRIMARY" ? 84 : 88)
    : (source.trustTier === "PRIMARY" ? 78 : 74);
  return confidence >= Math.max(floor, Math.min(source.autoPublishThreshold, 88));
}

async function structureCandidate(candidate: RawCandidate, source: ExtractionSource, knownVehicles: KnownVehicle[]): Promise<ExtractedOffer> {
  const text = compactText(candidate.text, 1800);
  let title = compactText(candidate.title, 180);
  if (titleIsInvalid(title)) title = bestOfferSentence(text);
  const titleValid = !titleIsInvalid(title);
  const combined = `${title} ${text}`;
  const benefit = benefitFromText(combined, candidate.structured);
  const dates = dateRangeFromText(combined, candidate.structured);
  const eligibility = eligibilityFromText(combined);
  const category = categoryFromText(combined, source);
  const models = knownModelsInText(combined, source.canonicalBrandCode, knownVehicles);
  const targetingScope = modelScope(combined, source, models);
  const extractedConditions = conditionsFromText(combined);
  const perTyrePriceAmount = benefit.priceAmount;
  const perTyreOriginalAmount = benefit.originalPriceAmount;
  const isPerTyrePriceOffer =
    category === "TYRES" &&
    perTyrePriceAmount !== null &&
    /\b(?:pour|par)\s+(?:un\s+)?(?:pneu|pneumatique)\b/i.test(combined);
  const conditions = isPerTyrePriceOffer
    ? `Prix indiqué pour un pneu : ${formatAmount(perTyrePriceAmount as number)} € TTC${
        perTyreOriginalAmount !== null
          ? ` au lieu de ${formatAmount(perTyreOriginalAmount)} € TTC`
          : ""
      }. Dimension, disponibilité, éventuels frais de montage et participation du réseau à confirmer.`
    : extractedConditions;
  const context = offerContext(source);
  const { confidence, reasons } = confidenceFor(candidate, source, titleValid, benefit, category, dates, targetingScope, conditions);
  const publishable = deterministicPublishable(candidate, source, titleValid, benefit, category, context, targetingScope, confidence, dates.endsAt, models);

  const targetingText = normalizeText(`${title} ${text} ${models.join(" ")}`).slice(0, 4000);
  const fingerprintSource = [source.sourceKey, candidate.url, title, benefit.kind, benefit.label, dates.startsAt ?? "", dates.endsAt ?? "", context, models.join("|")].map(normalizeText).join("::");
  const summary = text.replace(title, "").replace(/\s+/g, " ").trim().slice(0, 650) || text.slice(0, 650);

  return {
    fingerprint: await hashHex(fingerprintSource),
    title,
    summary,
    category,
    offerContext: context,
    targetingScope,
    targetingText,
    benefitKind: benefit.kind,
    benefitLabel: benefit.label,
    benefitValue: benefit.benefitValue,
    priceAmount: benefit.priceAmount,
    originalPriceAmount: benefit.originalPriceAmount,
    currency: "EUR",
    startsAt: dates.startsAt,
    endsAt: dates.endsAt,
    brands: source.canonicalBrandCode === "*" ? ["*"] : [source.canonicalBrandCode],
    modelPatterns: models,
    excludedModelPatterns: [],
    fuelTypes: eligibility.fuelTypes,
    excludedFuelTypes: eligibility.excludedFuelTypes,
    yearMin: eligibility.yearMin,
    yearMax: eligibility.yearMax,
    ageMin: eligibility.ageMin,
    ageMax: eligibility.ageMax,
    mileageMin: eligibility.mileageMin,
    mileageMax: eligibility.mileageMax,
    scheduleKeywords: scheduleKeywords(category, combined),
    conditionsSummary: conditions,
    eligibilityNotes: "Disponibilité, participation du réseau et conditions finales à confirmer sur la page source ou auprès du professionnel.",
    requiresExistingContract: eligibility.requiresExistingContract,
    requiresNetworkParticipation: source.trustTier !== "COMMUNITY_OR_MARKETPLACE",
    requiresManualEligibility: eligibility.requiresManualEligibility || targetingScope !== "MODEL",
    validationMarkers: distinctiveMarkers(title, benefit, dates, combined),
    officialUrl: candidate.url,
    extractionMethod: candidate.method,
    confidence,
    rejectionReasons: reasons,
    evidence: {
      engine_version: 6,
      source_key: source.sourceKey,
      method: candidate.method,
      title,
      benefit_explicit: benefit.explicit,
      benefit_evidence: benefit.evidenceText,
      model_matches: models,
      targeting_scope: targetingScope,
      source_purpose: source.sourcePurpose,
      starts_at: dates.startsAt,
      ends_at: dates.endsAt,
      normalized_excerpt: normalizeText(combined).slice(0, 900),
      // Promo V7 uses original local card text, not reconstructed labels or prices.
      raw_offer_excerpt: combined.slice(0, 5000),
    },
    publishable,
  };
}

export async function extractOffers(html: string, pageUrl: string, source: ExtractionSource, knownVehicles: KnownVehicle[]): Promise<ExtractedOffer[]> {
  const raw = deduplicateRawCandidates([
    ...extractJsonCandidates(html, pageUrl),
    ...extractHtmlCandidates(html, pageUrl),
    ...extractMetaCandidate(html, pageUrl),
  ]);
  const structured: ExtractedOffer[] = [];
  const seen = new Set<string>();
  for (const candidate of raw) {
    const offer = await structureCandidate(candidate, source, knownVehicles);
    if (!offer.title || seen.has(offer.fingerprint)) continue;
    seen.add(offer.fingerprint);
    structured.push(offer);
  }
  return structured
    .sort((a, b) => Number(b.publishable) - Number(a.publishable) || b.confidence - a.confidence || a.title.localeCompare(b.title))
    .slice(0, 80);
}

function normalizedHostname(value: string): string {
  return value.trim().toLowerCase().replace(/\.$/, "");
}

function hostnameAllowed(hostname: string, allowedHostnames: string[]): boolean {
  const normalized = normalizedHostname(hostname);
  return allowedHostnames.some((allowed) => normalized === normalizedHostname(allowed));
}

function cleanLink(rawHref: string, baseUrl: URL, allowedHostnames: string[]): URL | null {
  const trimmed = rawHref.trim();
  if (!trimmed || trimmed.startsWith("#") || trimmed.startsWith("mailto:") || trimmed.startsWith("tel:") || trimmed.startsWith("javascript:")) return null;
  let url: URL;
  try { url = new URL(trimmed, baseUrl); } catch { return null; }
  if (url.protocol !== "https:" || url.username || url.password || !hostnameAllowed(url.hostname, allowedHostnames)) return null;
  url.hash = "";
  for (const key of ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "gclid", "fbclid", "msclkid"]) url.searchParams.delete(key);
  return url.toString().length <= 1000 ? url : null;
}

function linkScore(url: URL, title: string): number {
  const value = normalizeText(`${url.pathname} ${url.search} ${title}`);
  let score = 0;
  const signals: Array<[RegExp, number]> = [
    [/\b(offre|offres|promotion|promotions|promo)\b/, 48],
    [/\b(entretien|revision|service|atelier|apres vente)\b/, 34],
    [/\b(forfait|remise|reduction|avantage|bon plan)\b/, 28],
    [/\b(financement|leasing|loa|lld|reprise)\b/, 22],
    [/\b(stock|disponible|vehicule neuf|occasion)\b/, 16],
    [/\b(pneu|batterie|climatisation|frein|pare brise|controle technique|accessoire)\b/, 24],
  ];
  for (const [pattern, weight] of signals) if (pattern.test(value)) score += weight;
  const currentYear = new Date().getUTCFullYear();
  if (value.includes(String(currentYear)) || value.includes(String(currentYear + 1))) score += 8;
  if (url.pathname === "/" || url.pathname.length < 3) score -= 20;
  return Math.max(0, Math.min(100, score));
}

export function extractOfferLinks(html: string, pageUrl: string, allowedHostnames: string[]): DiscoveredLink[] {
  const baseUrl = new URL(pageUrl);
  const candidates = new Map<string, DiscoveredLink>();
  const pattern = /<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  for (const match of html.matchAll(pattern)) {
    const url = cleanLink(match[1] ?? "", baseUrl, allowedHostnames);
    if (!url) continue;
    const title = compactText(stripHtml(match[2] ?? ""), 220);
    const score = linkScore(url, title);
    if (score < 40) continue;
    const key = url.toString();
    const existing = candidates.get(key);
    if (!existing || score > existing.score) candidates.set(key, { url: key, title, score });
  }
  return Array.from(candidates.values()).sort((a, b) => b.score - a.score || a.url.localeCompare(b.url)).slice(0, 60);
}