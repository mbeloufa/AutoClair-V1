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

const GENERIC_TITLE_WORDS = new Set([
  "offre",
  "offres",
  "promotion",
  "promotions",
  "nos",
  "du",
  "de",
  "des",
  "le",
  "la",
  "les",
  "votre",
  "vehicule",
  "voiture",
  "service",
  "services",
  "automobile",
  "france",
  "decouvrir",
  "en",
  "savoir",
  "plus",
]);

const COMMERCIAL_PATTERN =
  /\b(offre|promotion|promo|remise|reduction|economisez|avantage|forfait|gratuit|offert|a partir de|mensualite|loyer|prime|reprise|franchise)\b|\bdes\s+\d{1,6}/i;

const BENEFIT_PATTERN =
  /(?:\b\d{1,3}\s*%\b|\b\d{1,6}(?:[,.]\d{1,2})?\s*(?:€|eur\b)|\b(gratuit|offert|remise|reduction|economisez|prime|franchise)\b)/i;

const CONDITION_PATTERN =
  /\b(sous reserve|reserve a|valable|jusqu au|dans la limite|conditions|participant|eligibilite|hors|pour tout|pour toute|minimum|maximum|contrat|financement|reprise)\b/i;

export function decodeHtmlEntities(value: string): string {
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
    hellip: "…",
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

export function stripHtml(html: string): string {
  return decodeHtmlEntities(
    html
      .replace(/<!--[\s\S]*?-->/g, " ")
      .replace(
        /<(script|style|noscript|svg|template|iframe)\b[^>]*>[\s\S]*?<\/\1>/gi,
        " ",
      )
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
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[’‘`´]/g, "'")
    .replace(/[^a-z0-9%€]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function compactText(value: unknown, maximum = 600): string {
  if (typeof value !== "string") return "";
  return decodeHtmlEntities(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maximum);
}

function safeNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value !== "string") return null;

  const normalized = value
    .replace(/\s/g, "")
    .replace(",", ".")
    .replace(/[^\d.-]/g, "");

  if (!normalized) return null;

  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
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

function objectValue(
  object: Record<string, unknown>,
  keys: string[],
): unknown {
  for (const key of keys) {
    if (object[key] !== undefined && object[key] !== null) {
      return object[key];
    }
  }
  return null;
}

function typeNames(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  if (typeof value === "string") return [value];
  return [];
}

function objectLooksCommercial(object: Record<string, unknown>): boolean {
  const types = typeNames(object["@type"]).map((value) =>
    value.toLowerCase()
  );

  if (
    types.some((value) =>
      [
        "offer",
        "aggregateoffer",
        "product",
        "service",
        "vehicle",
        "car",
      ].includes(value)
    )
  ) {
    return true;
  }

  const keys = Object.keys(object).map((key) => key.toLowerCase());
  const hasPrice = keys.some((key) =>
    [
      "price",
      "lowprice",
      "highprice",
      "saleprice",
      "monthlypayment",
      "monthlyprice",
      "discount",
      "discountvalue",
      "saving",
      "amount",
      "loyer",
      "mensualite",
    ].includes(key)
  );
  const hasName = keys.some((key) =>
    ["name", "title", "headline", "label", "description"].includes(key)
  );

  return hasPrice && hasName;
}

function flattenCommercialObjects(
  value: unknown,
  output: Array<Record<string, unknown>>,
  depth = 0,
  state = { visited: 0 },
): void {
  if (depth > 10 || state.visited > 5_000) return;
  state.visited += 1;

  if (Array.isArray(value)) {
    for (const item of value.slice(0, 500)) {
      flattenCommercialObjects(item, output, depth + 1, state);
    }
    return;
  }

  if (!value || typeof value !== "object") return;

  const object = value as Record<string, unknown>;

  if (objectLooksCommercial(object)) {
    output.push(object);
  }

  for (const [key, child] of Object.entries(object)) {
    if (
      [
        "image",
        "images",
        "picture",
        "pictures",
        "icon",
        "icons",
        "tracking",
        "analytics",
        "translations",
      ].includes(key.toLowerCase())
    ) {
      continue;
    }
    flattenCommercialObjects(child, output, depth + 1, state);
  }
}

function rawCandidateFromObject(
  object: Record<string, unknown>,
  pageUrl: string,
  method: RawCandidate["method"],
  inheritedTitle = "",
): RawCandidate | null {
  const nestedOffer = objectValue(object, ["offers", "offer"]);
  const nested = Array.isArray(nestedOffer)
    ? nestedOffer.find((item) => item && typeof item === "object")
    : nestedOffer && typeof nestedOffer === "object"
    ? nestedOffer
    : null;

  const merged = nested
    ? { ...object, ...(nested as Record<string, unknown>) }
    : object;

  const title = compactText(
    objectValue(merged, [
      "name",
      "title",
      "headline",
      "label",
      "productName",
      "model",
    ]) ?? inheritedTitle,
    180,
  );

  const description = compactText(
    objectValue(merged, [
      "description",
      "summary",
      "subtitle",
      "shortDescription",
      "legalText",
      "terms",
      "conditions",
    ]),
    1_000,
  );

  const price = objectValue(merged, [
    "price",
    "lowPrice",
    "salePrice",
    "monthlyPayment",
    "monthlyPrice",
    "amount",
    "loyer",
    "mensualite",
  ]);

  const discount = objectValue(merged, [
    "discount",
    "discountValue",
    "saving",
    "remise",
    "reduction",
  ]);

  const validThrough = objectValue(merged, [
    "priceValidUntil",
    "validThrough",
    "endDate",
    "endsAt",
    "dateFin",
  ]);

  const startDate = objectValue(merged, [
    "validFrom",
    "startDate",
    "startsAt",
    "dateDebut",
  ]);

  const currency = compactText(
    objectValue(merged, ["priceCurrency", "currency", "devise"]),
    8,
  );

  const url = safeUrl(
    objectValue(merged, ["url", "offerUrl", "link"]),
    pageUrl,
  );

  const structuredPieces = [
    title,
    description,
    price === null || price === undefined ? "" : String(price),
    discount === null || discount === undefined ? "" : String(discount),
    validThrough === null || validThrough === undefined
      ? ""
      : String(validThrough),
    startDate === null || startDate === undefined
      ? ""
      : String(startDate),
    currency,
  ].filter(Boolean);

  const text = structuredPieces.join(" · ").trim();

  if (!title || !BENEFIT_PATTERN.test(normalizeText(text))) {
    return null;
  }

  return {
    title,
    text,
    url,
    method,
    structured: merged,
  };
}

function extractJsonCandidates(
  html: string,
  pageUrl: string,
): RawCandidate[] {
  const candidates: RawCandidate[] = [];
  const scriptPattern =
    /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let totalJsonBytes = 0;

  for (const match of html.matchAll(scriptPattern)) {
    const attributes = match[1] ?? "";
    const body = (match[2] ?? "").trim();

    if (!body || body.length > 600_000) continue;

    const isJsonLd =
      /type\s*=\s*["']application\/ld\+json["']/i.test(attributes);
    const isEmbeddedJson =
      /type\s*=\s*["']application\/json["']/i.test(attributes) ||
      /id\s*=\s*["'](__NEXT_DATA__|__NUXT_DATA__|__APOLLO_STATE__)["']/i
        .test(attributes);

    if (!isJsonLd && !isEmbeddedJson) continue;

    totalJsonBytes += body.length;
    if (totalJsonBytes > 1_200_000) break;

    let parsed: unknown;
    try {
      parsed = JSON.parse(
        body
          .replace(/^\s*<!--/, "")
          .replace(/-->\s*$/, ""),
      );
    } catch {
      continue;
    }

    const objects: Array<Record<string, unknown>> = [];
    flattenCommercialObjects(parsed, objects);

    for (const object of objects.slice(0, 250)) {
      const candidate = rawCandidateFromObject(
        object,
        pageUrl,
        isJsonLd ? "JSON_LD" : "EMBEDDED_JSON",
      );
      if (candidate) candidates.push(candidate);
    }
  }

  return candidates;
}

function firstHeading(blockHtml: string): string {
  const heading = blockHtml.match(
    /<(h[1-6]|strong|b)\b[^>]*>([\s\S]*?)<\/\1>/i,
  );

  if (heading) {
    return compactText(stripHtml(heading[2] ?? ""), 180);
  }

  const plain = stripHtml(blockHtml);
  return plain
    .split(/(?<=[.!?])\s+|\n+/)
    .map((part) => part.trim())
    .find((part) => part.length >= 8 && part.length <= 180) ?? "";
}

function extractHtmlCandidates(
  html: string,
  pageUrl: string,
): RawCandidate[] {
  const candidates: RawCandidate[] = [];
  const patterns = [
    /<(article|section|li|aside)\b[^>]*>([\s\S]*?)<\/\1>/gi,
    /<div\b[^>]*(?:class|id)\s*=\s*["'][^"']*(?:offer|offre|promo|deal|campaign|card|teaser|product)[^"']*["'][^>]*>([\s\S]*?)<\/div>/gi,
    /<(h[1-4])\b[^>]*>([\s\S]*?)<\/\1>([\s\S]{0,1400}?)(?=<h[1-4]\b|$)/gi,
  ];

  for (const pattern of patterns) {
    let seen = 0;

    for (const match of html.matchAll(pattern)) {
      if (seen >= 350) break;
      seen += 1;

      const blockHtml = match[0];
      const plain = stripHtml(blockHtml)
        .replace(/\s+/g, " ")
        .trim();

      if (plain.length < 55 || plain.length > 2_200) continue;

      const normalized = normalizeText(plain);
      if (
        !COMMERCIAL_PATTERN.test(normalized) ||
        !BENEFIT_PATTERN.test(normalized)
      ) {
        continue;
      }

      const title = firstHeading(blockHtml);
      if (!title || title.length < 5) continue;

      candidates.push({
        title,
        text: plain,
        url: pageUrl,
        method: "HTML_CARD",
        structured: {},
      });
    }
  }

  return candidates;
}

function metaContent(html: string, names: string[]): string {
  for (const name of names) {
    const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const patterns = [
      new RegExp(
        `<meta\\b[^>]*(?:property|name)\\s*=\\s*["']${escaped}["'][^>]*content\\s*=\\s*["']([^"']+)["'][^>]*>`,
        "i",
      ),
      new RegExp(
        `<meta\\b[^>]*content\\s*=\\s*["']([^"']+)["'][^>]*(?:property|name)\\s*=\\s*["']${escaped}["'][^>]*>`,
        "i",
      ),
    ];

    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match?.[1]) return compactText(match[1], 700);
    }
  }

  return "";
}

function extractMetaCandidate(
  html: string,
  pageUrl: string,
): RawCandidate[] {
  const title =
    metaContent(html, ["og:title", "twitter:title"]) ||
    compactText(
      html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? "",
      180,
    );
  const description = metaContent(
    html,
    ["og:description", "description", "twitter:description"],
  );
  const price = metaContent(
    html,
    [
      "product:price:amount",
      "og:price:amount",
      "product:sale_price:amount",
    ],
  );
  const currency = metaContent(
    html,
    ["product:price:currency", "og:price:currency"],
  );

  const text = [title, description, price, currency]
    .filter(Boolean)
    .join(" · ");

  if (
    !title ||
    !COMMERCIAL_PATTERN.test(normalizeText(text)) ||
    !BENEFIT_PATTERN.test(normalizeText(text))
  ) {
    return [];
  }

  return [{
    title,
    text,
    url: pageUrl,
    method: "META",
    structured: {
      price,
      currency,
    },
  }];
}

function deduplicateRawCandidates(
  candidates: RawCandidate[],
): RawCandidate[] {
  const deduplicated = new Map<string, RawCandidate>();

  for (const candidate of candidates) {
    const key = normalizeText(
      `${candidate.title} ${candidate.text.slice(0, 250)}`,
    ).slice(0, 420);

    if (!key) continue;

    const existing = deduplicated.get(key);
    const rank = (method: RawCandidate["method"]): number => switchMethod(method);
    if (!existing || rank(candidate.method) > rank(existing.method)) {
      deduplicated.set(key, candidate);
    }
  }

  return Array.from(deduplicated.values()).slice(0, 120);
}

function switchMethod(method: RawCandidate["method"]): number {
  if (method === "JSON_LD") return 4;
  if (method === "EMBEDDED_JSON") return 3;
  if (method === "HTML_CARD") return 2;
  return 1;
}

function parsePrice(text: string): {
  price: number | null;
  original: number | null;
  monthly: boolean;
  from: boolean;
} {
  const normalized = normalizeText(text);
  const matches = Array.from(
    normalized.matchAll(
      /\b(a partir de|des|pour|seulement|prix)?\s*(\d{1,6}(?:[,.]\d{1,2})?)\s*(?:€|eur)(?:\s*(?:par|\/)\s*(mois|jour))?/gi,
    ),
  );

  let price: number | null = null;
  let monthly = false;
  let from = false;

  for (const match of matches) {
    const amount = safeNumber(match[2]);
    if (amount === null || amount <= 0 || amount > 500_000) continue;

    price ??= amount;
    from ||= normalizeText(match[1] ?? "").includes("a partir");
    monthly ||= Boolean(match[3]);
  }

  const originalMatch = normalized.match(
    /\b(?:au lieu de|prix catalogue|prix initial|ancien prix)\s*(\d{1,6}(?:[,.]\d{1,2})?)\s*(?:€|eur)\b/i,
  );

  return {
    price,
    original: safeNumber(originalMatch?.[1]),
    monthly,
    from,
  };
}

function parsePercent(text: string): number | null {
  const normalized = normalizeText(text);
  const match = normalized.match(
    /(?:-|jusqu a|remise de|reduction de|economisez)?\s*(\d{1,3})\s*%/i,
  );
  const value = safeNumber(match?.[1]);
  if (value === null || value <= 0 || value > 100) return null;
  return value;
}

function benefitFromText(
  text: string,
  structured: Record<string, unknown>,
): {
  kind: ExtractedOffer["benefitKind"];
  label: string;
  benefitValue: number | null;
  priceAmount: number | null;
  originalPriceAmount: number | null;
  explicit: boolean;
} {
  const normalized = normalizeText(text);
  const percent = parsePercent(text);
  const parsedPrice = parsePrice(text);
  const structuredPrice = safeNumber(
    objectValue(structured, [
      "price",
      "lowPrice",
      "salePrice",
      "monthlyPayment",
      "monthlyPrice",
      "amount",
      "loyer",
      "mensualite",
    ]),
  );
  const structuredOriginal = safeNumber(
    objectValue(structured, [
      "highPrice",
      "originalPrice",
      "listPrice",
      "oldPrice",
      "prixCatalogue",
    ]),
  );
  const price = {
    ...parsedPrice,
    price: structuredPrice ?? parsedPrice.price,
    original: structuredOriginal ?? parsedPrice.original,
  };
  const reimbursement = normalized.match(
    /\b(?:franchise|remboursement|prise en charge)[^€]{0,80}(?:jusqu a|limite de)?\s*(\d{1,6}(?:[,.]\d{1,2})?)\s*(?:€|eur)/i,
  );
  const reimbursementValue = safeNumber(reimbursement?.[1]);

  if (percent !== null) {
    return {
      kind: "PERCENT",
      label: `Jusqu’à -${percent.toString().replace(".", ",")} %`,
      benefitValue: percent,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
    };
  }

  if (reimbursementValue !== null) {
    return {
      kind: "REIMBURSEMENT",
      label: `Prise en charge jusqu’à ${reimbursementValue
        .toString()
        .replace(".", ",")} €`,
      benefitValue: reimbursementValue,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
    };
  }

  if (/\b(gratuit|offert|offerte|offerts|offertes)\b/i.test(normalized)) {
    return {
      kind: "FREE_SERVICE",
      label: "Prestation ou avantage offert",
      benefitValue: null,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
    };
  }

  if (price.price !== null) {
    const suffix = price.monthly ? " par mois" : "";
    return {
      kind: price.from ? "FROM_PRICE" : "FIXED_PRICE",
      label: `${price.from ? "À partir de " : ""}${price.price
        .toString()
        .replace(".", ",")} €${suffix}`,
      benefitValue: null,
      priceAmount: price.price,
      originalPriceAmount: price.original,
      explicit: true,
    };
  }

  if (/\b(remise|reduction|promotion|avantage|prime)\b/i.test(normalized)) {
    return {
      kind: "INFO",
      label: "Avantage commercial à confirmer",
      benefitValue: null,
      priceAmount: null,
      originalPriceAmount: null,
      explicit: true,
    };
  }

  return {
    kind: "INFO",
    label: "Conditions commerciales à consulter",
    benefitValue: null,
    priceAmount: null,
    originalPriceAmount: null,
    explicit: false,
  };
}

function isoDate(year: number, month: number, day: number): string | null {
  if (
    year < 2020 ||
    year > 2100 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31
  ) {
    return null;
  }

  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }

  return `${year.toString().padStart(4, "0")}-${month
    .toString()
    .padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
}

function parseFrenchDate(
  dayRaw: string,
  monthRaw: string,
  yearRaw: string | undefined,
  fallbackYear: number,
): string | null {
  const day = Number.parseInt(dayRaw, 10);
  const month = MONTHS[normalizeText(monthRaw)];
  const year = yearRaw
    ? Number.parseInt(yearRaw, 10)
    : fallbackYear;

  if (!month) return null;
  return isoDate(year, month, day);
}

function dateRangeFromText(
  text: string,
  structured: Record<string, unknown>,
): { startsAt: string | null; endsAt: string | null } {
  const normalized = normalizeText(text);
  const currentYear = new Date().getUTCFullYear();

  const structuredStart = compactText(
    objectValue(structured, [
      "validFrom",
      "startDate",
      "startsAt",
      "dateDebut",
    ]),
    30,
  );
  const structuredEnd = compactText(
    objectValue(structured, [
      "priceValidUntil",
      "validThrough",
      "endDate",
      "endsAt",
      "dateFin",
    ]),
    30,
  );

  const parseStructured = (value: string): string | null => {
    if (!value) return null;
    const iso = value.match(/\b(20\d{2})-(\d{2})-(\d{2})\b/);
    if (iso) {
      return isoDate(
        Number.parseInt(iso[1], 10),
        Number.parseInt(iso[2], 10),
        Number.parseInt(iso[3], 10),
      );
    }
    return null;
  };

  let startsAt = parseStructured(structuredStart);
  let endsAt = parseStructured(structuredEnd);

  const numericDates = Array.from(
    normalized.matchAll(
      /\b(0?[1-9]|[12]\d|3[01])[\/.-](0?[1-9]|1[0-2])[\/.-](20\d{2})\b/g,
    ),
  )
    .map((match) =>
      isoDate(
        Number.parseInt(match[3], 10),
        Number.parseInt(match[2], 10),
        Number.parseInt(match[1], 10),
      )
    )
    .filter((value): value is string => Boolean(value));

  const frenchDates = Array.from(
    normalized.matchAll(
      /\b(0?[1-9]|[12]\d|3[01])\s+(janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre|octobre|novembre|decembre)(?:\s+(20\d{2}))?\b/g,
    ),
  ).map((match) => ({
    raw: match[0],
    date: parseFrenchDate(
      match[1],
      match[2],
      match[3],
      currentYear,
    ),
    index: match.index ?? 0,
  }));

  const validFrenchDates = frenchDates.filter(
    (item): item is typeof item & { date: string } => Boolean(item.date),
  );

  if (!startsAt && numericDates.length >= 2) {
    startsAt = numericDates[0];
  }
  if (!endsAt && numericDates.length >= 1) {
    endsAt = numericDates[numericDates.length - 1];
  }

  if (!endsAt && validFrenchDates.length > 0) {
    const last = validFrenchDates[validFrenchDates.length - 1];
    const before = normalized.slice(Math.max(0, last.index - 70), last.index);

    if (
      /\b(jusqu au|au|fin|expire|valable|validite)\b/.test(before) ||
      validFrenchDates.length >= 2
    ) {
      endsAt = last.date;
    }
  }

  if (!startsAt && validFrenchDates.length >= 2) {
    startsAt = validFrenchDates[0].date;
  }

  if (startsAt && endsAt && startsAt > endsAt) {
    const start = startsAt;
    startsAt = endsAt;
    endsAt = start;
  }

  return { startsAt, endsAt };
}

function integerFromPattern(
  normalized: string,
  pattern: RegExp,
): number | null {
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

  const betweenAge = normalized.match(
    /\b(?:entre|de)\s*(\d{1,2})\s*(?:et|a)\s*(\d{1,2})\s*ans\b/,
  );
  if (betweenAge) {
    ageMin = Number.parseInt(betweenAge[1], 10);
    ageMax = Number.parseInt(betweenAge[2], 10);
  } else {
    const moreThan = integerFromPattern(
      normalized,
      /\b(?:plus de|age de plus de)\s*(\d{1,2})\s*ans\b/,
    );
    const atLeast = integerFromPattern(
      normalized,
      /\b(?:au moins|minimum)\s*(\d{1,2})\s*ans\b/,
    );
    const lessThan = integerFromPattern(
      normalized,
      /\b(?:moins de|age inferieur a)\s*(\d{1,2})\s*ans\b/,
    );
    const atMost = integerFromPattern(
      normalized,
      /\b(?:maximum|au plus)\s*(\d{1,2})\s*ans\b/,
    );

    if (moreThan !== null) ageMin = moreThan + 1;
    if (atLeast !== null) ageMin = atLeast;
    if (lessThan !== null) ageMax = Math.max(0, lessThan - 1);
    if (atMost !== null) ageMax = atMost;
  }

  const yearRange = normalized.match(
    /\b(?:de|entre|immatricule(?:e)?s? de)\s*(20\d{2})\s*(?:a|et|-)\s*(20\d{2})\b/,
  );

  const mileageMax = integerFromPattern(
    normalized.replace(/\s+/g, ""),
    /\b(?:moinsde|maximum|jusqua|limitede)(\d{3,6})km\b/,
  );

  const mileageMin = integerFromPattern(
    normalized.replace(/\s+/g, ""),
    /\b(?:plusde|minimum|apartirde)(\d{3,6})km\b/,
  );

  const fuelTypes: string[] = [];
  const excludedFuelTypes: string[] = [];

  const fuelMap: Array<[string, RegExp]> = [
    ["electric", /\b(electrique|100 electrique|ev)\b/],
    ["hybrid", /\b(hybride|hybrid)\b/],
    ["lpg", /\b(gpl|lpg)\b/],
    ["diesel", /\b(diesel|gazole)\b/],
    ["petrol", /\b(essence|petrol)\b/],
  ];

  for (const [fuel, pattern] of fuelMap) {
    if (!pattern.test(normalized)) continue;

    const location = normalized.search(pattern);
    const prefix = normalized.slice(Math.max(0, location - 35), location);

    if (/\b(hors|exclu|sauf|non compatible)\b/.test(prefix)) {
      excludedFuelTypes.push(fuel);
    } else {
      fuelTypes.push(fuel);
    }
  }

  return {
    yearMin: yearRange ? Number.parseInt(yearRange[1], 10) : null,
    yearMax: yearRange ? Number.parseInt(yearRange[2], 10) : null,
    ageMin,
    ageMax,
    mileageMin,
    mileageMax,
    fuelTypes: Array.from(new Set(fuelTypes)),
    excludedFuelTypes: Array.from(new Set(excludedFuelTypes)),
    requiresExistingContract:
      /\b(contrat (?:d )?entretien (?:valide|en cours)|reserve aux titulaires d un contrat)\b/
        .test(normalized),
    requiresManualEligibility: CONDITION_PATTERN.test(normalized),
  };
}

function categoryFromText(
  text: string,
  source: ExtractionSource,
): string {
  const normalized = normalizeText(text);

  if (source.sourcePurpose === "VEHICLE_PURCHASE") {
    return source.endpointType === "USED_OR_STOCK"
      ? "USED_VEHICLE"
      : "NEW_VEHICLE";
  }

  const rules: Array<[string, RegExp]> = [
    ["INSPECTION", /\b(controle technique|contre visite)\b/],
    ["WINDSCREEN", /\b(pare brise|vitrage|bris de glace)\b/],
    ["TYRES", /\b(pneu|pneumatique|jante)\b/],
    ["BATTERY", /\b(batterie|demarrage)\b/],
    ["CLIMATE", /\b(climatisation|recharge clim|filtre habitacle)\b/],
    ["BODYWORK", /\b(carrosserie|peinture|rayure|debosselage)\b/],
    ["CONTRACT", /\b(contrat d entretien|service care|flexcare)\b/],
    ["INSURANCE", /\b(assurance|protection financiere)\b/],
    ["ASSISTANCE", /\b(assistance|depannage|remorquage)\b/],
    ["FINANCE", /\b(financement|credit|loa|lld|leasing|loyer)\b/],
    ["PARTS", /\b(piece|pieces|filtre|plaquette|disque|essuie glace)\b/],
    ["ACCESSORIES", /\b(accessoire|barres de toit|coffre de toit|attelage)\b/],
    ["MAINTENANCE", /\b(entretien|revision|vidange|frein|forfait)\b/],
  ];

  for (const [category, pattern] of rules) {
    if (pattern.test(normalized)) return category;
  }

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
    ACCESSORIES: ["accessoire"],
    MAINTENANCE: [
      "entretien",
      "revision",
      "vidange",
      "filtre",
      "frein",
      "distribution",
    ],
  };

  const possible = byCategory[category] ?? [];
  return possible.filter((keyword) => normalized.includes(keyword));
}

function knownModelsInText(
  text: string,
  sourceBrand: string,
  knownVehicles: KnownVehicle[],
): string[] {
  const normalized = ` ${normalizeText(text)} `;
  const matches = new Set<string>();

  for (const vehicle of knownVehicles) {
    if (
      sourceBrand !== "*" &&
      vehicle.brand !== sourceBrand
    ) {
      continue;
    }

    const model = normalizeText(vehicle.model);
    if (!model || model.length < 2) continue;

    // La correspondance par expression complète protège les modèles comme
    // « Model 3 » ou « Golf 8 », dont la partie numérique isolée serait trop
    // ambiguë. Le repli par tokens couvre les libellés enrichis ou réordonnés.
    if (normalized.includes(` ${model} `)) {
      matches.add(vehicle.model.trim());
      continue;
    }

    const tokens = model
      .split(/\s+/)
      .filter((token) => token.length >= 2)
      .filter((token) => ![
        "model",
        "modele",
        "nouveau",
        "nouvelle",
      ].includes(token));

    if (
      tokens.length > 0 &&
      tokens.every((token) =>
        normalized.includes(` ${token} `)
      )
    ) {
      matches.add(vehicle.model.trim());
    }
  }

  return Array.from(matches).slice(0, 20);
}

function modelScope(
  text: string,
  source: ExtractionSource,
  models: string[],
): ExtractedOffer["targetingScope"] {
  if (models.length > 0) return "MODEL";

  if (source.sourcePurpose === "VEHICLE_PURCHASE") {
    return "UNKNOWN";
  }

  if (source.canonicalBrandCode === "*") {
    return "ALL_VEHICLES";
  }

  const normalized = normalizeText(text);
  if (
    /\b(modele|modeles|gamme|uniquement pour|compatible avec)\b/
      .test(normalized)
  ) {
    return "UNKNOWN";
  }

  return "BRAND";
}

function cleanTitle(title: string, text: string): string {
  const compact = compactText(title, 180);
  if (compact.length >= 6) return compact;

  return compactText(
    text.split(/(?<=[.!?])\s+|\n+/)[0] ?? "Offre automobile",
    180,
  );
}

function conditionsFromText(text: string): string {
  const sentences = text
    .split(/(?<=[.!?;])\s+|\n+/)
    .map((value) => value.trim())
    .filter((value) => value.length >= 20 && value.length <= 420)
    .filter((value) => CONDITION_PATTERN.test(normalizeText(value)));

  return Array.from(new Set(sentences))
    .slice(0, 3)
    .join(" ")
    .slice(0, 750);
}

function distinctiveMarkers(
  title: string,
  benefitLabel: string,
  endsAt: string | null,
  text: string,
): string[] {
  const markers = new Set<string>();

  const normalizedTitle = normalizeText(title);
  if (normalizedTitle.length >= 10) markers.add(normalizedTitle);

  const normalizedBenefit = normalizeText(benefitLabel);
  if (normalizedBenefit.length >= 7) markers.add(normalizedBenefit);

  if (endsAt) markers.add(endsAt);

  const sentences = text
    .split(/(?<=[.!?;])\s+/)
    .map(normalizeText)
    .filter((value) => value.length >= 20 && value.length <= 140)
    .filter((value) => BENEFIT_PATTERN.test(value));

  for (const sentence of sentences.slice(0, 2)) {
    markers.add(sentence);
  }

  return Array.from(markers).slice(0, 4);
}

async function hashHex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function confidenceFor(
  candidate: RawCandidate,
  source: ExtractionSource,
  benefitExplicit: boolean,
  category: string,
  dates: { startsAt: string | null; endsAt: string | null },
  modelPatterns: string[],
  targetingScope: ExtractedOffer["targetingScope"],
  conditions: string,
): { confidence: number; reasons: string[] } {
  let score = 0;
  const reasons: string[] = [];

  if (source.trustTier === "PRIMARY") score += 22;
  else if (source.trustTier === "PROFESSIONAL") score += 14;
  else {
    score += 2;
    reasons.push("Source communautaire ou marketplace");
  }

  if (source.endpointType === "OFFERS" || source.endpointType === "AFTER_SALES") {
    score += 13;
  } else if (source.endpointType === "HOME_OR_CATALOG") {
    score += 3;
  } else {
    score += 7;
  }

  if (candidate.method === "JSON_LD") score += 20;
  else if (candidate.method === "EMBEDDED_JSON") score += 16;
  else if (candidate.method === "HTML_CARD") score += 11;
  else score += 6;

  if (candidate.title.length >= 8) score += 8;
  if (benefitExplicit) score += 20;
  else {
    score -= 25;
    reasons.push("Avantage commercial non chiffré ou non explicite");
  }

  if (category !== "OTHER") score += 6;
  else reasons.push("Catégorie non déterminée");

  if (dates.startsAt || dates.endsAt) score += 8;
  if (conditions) score += 4;

  if (source.canonicalBrandCode !== "*") score += 8;
  else score += 2;

  if (source.sourcePurpose === "VEHICLE_PURCHASE") {
    if (modelPatterns.length > 0 && targetingScope === "MODEL") {
      score += 16;
    } else {
      score -= 28;
      reasons.push(
        "Offre d’achat sans modèle configuré clairement identifié",
      );
    }
  } else if (targetingScope === "UNKNOWN") {
    score -= 12;
    reasons.push("Périmètre de modèles ambigu");
  }

  const titleWords = normalizeText(candidate.title)
    .split(/\s+/)
    .filter(Boolean);
  const meaningfulTitleWords = titleWords.filter(
    (word) => !GENERIC_TITLE_WORDS.has(word),
  );

  if (meaningfulTitleWords.length === 0) {
    score -= 15;
    reasons.push("Titre trop générique");
  }

  if (candidate.text.length > 1_900) {
    score -= 8;
    reasons.push("Bloc de page trop large");
  }

  score = Math.max(0, Math.min(100, Math.round(score)));
  return { confidence: score, reasons };
}

function offerContext(
  source: ExtractionSource,
): ExtractedOffer["offerContext"] {
  if (source.sourcePurpose === "VEHICLE_PURCHASE") {
    return "VEHICLE_PURCHASE";
  }
  if (source.sourcePurpose === "FINANCE_INSURANCE") {
    return "FINANCE_INSURANCE";
  }
  return "CURRENT_VEHICLE";
}

async function structureCandidate(
  candidate: RawCandidate,
  source: ExtractionSource,
  knownVehicles: KnownVehicle[],
): Promise<ExtractedOffer> {
  const title = cleanTitle(candidate.title, candidate.text);
  const text = compactText(candidate.text, 2_200);
  const normalized = normalizeText(`${title} ${text}`);
  const benefit = benefitFromText(text, candidate.structured);
  const dates = dateRangeFromText(text, candidate.structured);
  const eligibility = eligibilityFromText(text);
  const category = categoryFromText(text, source);
  const models = knownModelsInText(
    `${title} ${text}`,
    source.canonicalBrandCode,
    knownVehicles,
  );
  const targetingScope = modelScope(text, source, models);
  const conditions = conditionsFromText(text);
  const context = offerContext(source);

  const { confidence, reasons } = confidenceFor(
    candidate,
    source,
    benefit.explicit,
    category,
    dates,
    models,
    targetingScope,
    conditions,
  );

  const publishable =
    source.publicationPolicy === "AUTO_HIGH_CONFIDENCE" &&
    source.trustTier !== "COMMUNITY_OR_MARKETPLACE" &&
    confidence >= source.autoPublishThreshold &&
    benefit.explicit &&
    targetingScope !== "UNKNOWN" &&
    (
      context !== "VEHICLE_PURCHASE" ||
      models.length > 0
    );

  const targetingText = normalizeText(
    `${title} ${text} ${models.join(" ")}`,
  ).slice(0, 4_000);

  const fingerprintSource = [
    source.sourceKey,
    candidate.url,
    title,
    benefit.kind,
    benefit.label,
    dates.startsAt ?? "",
    dates.endsAt ?? "",
    context,
    models.join("|"),
  ].map(normalizeText).join("::");

  const summary = text
    .replace(title, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 650) || text.slice(0, 650);

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
    brands: source.canonicalBrandCode === "*"
      ? ["*"]
      : [source.canonicalBrandCode],
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
    scheduleKeywords: scheduleKeywords(category, text),
    conditionsSummary: conditions,
    eligibilityNotes:
      "Prix, disponibilité, participation du réseau et conditions finales " +
      "à confirmer sur la page source ou auprès du professionnel.",
    requiresExistingContract: eligibility.requiresExistingContract,
    requiresNetworkParticipation:
      source.trustTier !== "COMMUNITY_OR_MARKETPLACE",
    requiresManualEligibility:
      eligibility.requiresManualEligibility ||
      targetingScope === "UNKNOWN" ||
      context !== "CURRENT_VEHICLE",
    validationMarkers: distinctiveMarkers(
      title,
      benefit.label,
      dates.endsAt,
      text,
    ),
    officialUrl: candidate.url,
    extractionMethod: candidate.method,
    confidence,
    rejectionReasons: reasons,
    evidence: {
      source_key: source.sourceKey,
      method: candidate.method,
      title,
      benefit_explicit: benefit.explicit,
      model_matches: models,
      targeting_scope: targetingScope,
      source_purpose: source.sourcePurpose,
      normalized_excerpt: normalized.slice(0, 800),
    },
    publishable,
  };
}

export async function extractOffers(
  html: string,
  pageUrl: string,
  source: ExtractionSource,
  knownVehicles: KnownVehicle[],
): Promise<ExtractedOffer[]> {
  const raw = deduplicateRawCandidates([
    ...extractJsonCandidates(html, pageUrl),
    ...extractHtmlCandidates(html, pageUrl),
    ...extractMetaCandidate(html, pageUrl),
  ]);

  const structured: ExtractedOffer[] = [];
  const seen = new Set<string>();

  for (const candidate of raw) {
    const offer = await structureCandidate(
      candidate,
      source,
      knownVehicles,
    );

    if (seen.has(offer.fingerprint)) continue;
    seen.add(offer.fingerprint);
    structured.push(offer);
  }

  return structured
    .sort((a, b) =>
      Number(b.publishable) - Number(a.publishable) ||
      b.confidence - a.confidence ||
      a.title.localeCompare(b.title)
    )
    .slice(0, 60);
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

function cleanLink(
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
  for (const key of [
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    "gclid",
    "fbclid",
    "msclkid",
  ]) {
    url.searchParams.delete(key);
  }

  return url.toString().length <= 1_000 ? url : null;
}

function linkScore(url: URL, title: string): number {
  const value = normalizeText(
    `${url.pathname} ${url.search} ${title}`,
  );

  let score = 0;
  const signals: Array<[RegExp, number]> = [
    [/\b(offre|offres|promotion|promotions|promo)\b/, 48],
    [/\b(entretien|revision|service|atelier|apres vente)\b/, 34],
    [/\b(forfait|remise|reduction|avantage|bon plan)\b/, 28],
    [/\b(financement|leasing|loa|lld|reprise)\b/, 22],
    [/\b(stock|disponible|vehicule neuf|occasion)\b/, 16],
    [/\b(pneu|batterie|climatisation|frein|pare brise)\b/, 24],
  ];

  for (const [pattern, weight] of signals) {
    if (pattern.test(value)) score += weight;
  }

  const currentYear = new Date().getUTCFullYear();
  if (
    value.includes(String(currentYear)) ||
    value.includes(String(currentYear + 1))
  ) {
    score += 8;
  }

  if (url.pathname === "/" || url.pathname.length < 3) score -= 20;
  return Math.max(0, Math.min(100, score));
}

export function extractOfferLinks(
  html: string,
  pageUrl: string,
  allowedHostnames: string[],
): DiscoveredLink[] {
  const baseUrl = new URL(pageUrl);
  const candidates = new Map<string, DiscoveredLink>();
  const pattern =
    /<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;

  for (const match of html.matchAll(pattern)) {
    const url = cleanLink(
      match[1] ?? "",
      baseUrl,
      allowedHostnames,
    );
    if (!url) continue;

    const title = compactText(stripHtml(match[2] ?? ""), 220);
    const score = linkScore(url, title);
    if (score < 40) continue;

    const key = url.toString();
    const existing = candidates.get(key);
    if (!existing || score > existing.score) {
      candidates.set(key, { url: key, title, score });
    }
  }

  return Array.from(candidates.values())
    .sort((a, b) =>
      b.score - a.score ||
      a.url.localeCompare(b.url)
    )
    .slice(0, 40);
}
