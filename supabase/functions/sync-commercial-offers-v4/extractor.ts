export type OfferSource = {
  id: string;
  sourceKey: string;
  url: string;
  brand: string;
  official: boolean;
};

export type ExtractedOffer = {
  offerKey: string;
  title: string;
  summary: string;
  category: string;
  offerContext: 'CURRENT_VEHICLE' | 'VEHICLE_PURCHASE';
  benefitKind: string;
  benefitLabel: string;
  benefitValue: number | null;
  priceAmount: number | null;
  startsAt: string | null;
  endsAt: string | null;
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
  conditionsSummary: string;
  eligibilityNotes: string;
  requiresExistingContract: boolean;
  requiresNetworkParticipation: boolean;
  requiresManualEligibility: boolean;
  validationMarkers: string[];
  confidence: number;
  rawExcerpt: string;
};

const MONTHS: Record<string, number> = {
  janvier: 1, fevrier: 2, février: 2, mars: 3, avril: 4, mai: 5, juin: 6,
  juillet: 7, aout: 8, août: 8, septembre: 9, octobre: 10, novembre: 11, decembre: 12, décembre: 12,
};

const BRAND_ALIASES: Array<[string, string[]]> = [
  ['alfa romeo', ['alfa-romeo', 'alfaromeo']], ['land rover', ['land-rover', 'landrover']],
  ['mercedes-benz', ['mercedes', 'mercedes-benz']], ['volkswagen', ['volkswagen', 'vw']],
  ['citroen', ['citroen', 'citroën']], ['ds', ['dsautomobiles', 'ds-automobiles']],
  ['renault', ['renault']], ['dacia', ['dacia']], ['peugeot', ['peugeot']], ['audi', ['audi']],
  ['skoda', ['skoda', 'škoda']], ['seat', ['seat']], ['cupra', ['cupra']], ['porsche', ['porsche']],
  ['bmw', ['bmw']], ['mini', ['mini']], ['smart', ['smart']], ['opel', ['opel']], ['fiat', ['fiat']],
  ['abarth', ['abarth']], ['jeep', ['jeep']], ['nissan', ['nissan']], ['toyota', ['toyota']],
  ['lexus', ['lexus']], ['ford', ['ford']], ['hyundai', ['hyundai']], ['kia', ['kia']],
  ['volvo', ['volvo']], ['mazda', ['mazda']], ['honda', ['honda']], ['suzuki', ['suzuki']],
  ['mitsubishi', ['mitsubishi']], ['tesla', ['tesla']], ['mg', ['mgmotor', 'mg-motor']],
  ['jaguar', ['jaguar']], ['subaru', ['subaru']], ['isuzu', ['isuzu']], ['alpine', ['alpine']],
  ['polestar', ['polestar']], ['byd', ['byd']], ['xpeng', ['xpeng']], ['leapmotor', ['leapmotor']],
  ['kmg', ['kgm', 'ssangyong']],
];

export function normalizeToken(value: unknown): string {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/&nbsp;|&#160;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/[^a-z0-9%€+\-.,/ ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function detectBrand(value: string): string {
  const normalized = normalizeToken(value).replace(/\s+/g, '-');
  for (const [brand, aliases] of BRAND_ALIASES) {
    if (aliases.some((alias) => normalized.includes(normalizeToken(alias).replace(/\s+/g, '-')))) return brand;
  }
  return '';
}

function decodeHtml(value: string): string {
  return value
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&euro;|&#8364;/gi, '€')
    .replace(/&agrave;/gi, 'à').replace(/&eacute;/gi, 'é').replace(/&egrave;/gi, 'è')
    .replace(/&ecirc;/gi, 'ê').replace(/&ocirc;/gi, 'ô').replace(/&ucirc;/gi, 'û')
    .replace(/&ccedil;/gi, 'ç').replace(/&rsquo;|&#8217;/gi, '’')
    .replace(/&quot;/gi, '"').replace(/&#39;/gi, "'");
}

export function htmlToText(html: string): string {
  return decodeHtml(html)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|li|h1|h2|h3|h4|section|article|div)>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s*\n+/g, '\n')
    .trim();
}

function embeddedDataToText(html: string): string {
  const chunks: string[] = [];
  const scriptPattern = /<script[^>]*(?:type=["']application\/ld\+json["']|id=["']__NEXT_DATA__["'])[^>]*>([\s\S]*?)<\/script>/gi;
  for (const match of html.matchAll(scriptPattern)) {
    const raw = match[1]
      .replace(/\\u20ac/gi, '€')
      .replace(/\\u00e9/gi, 'é')
      .replace(/\\u00e8/gi, 'è')
      .replace(/\\u00e0/gi, 'à')
      .replace(/\\n/g, '\n')
      .replace(/[{}[\]",:]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (raw.length >= 20) chunks.push(raw.slice(0, 300000));
  }
  return decodeHtml(chunks.join('\n'));
}

function hashText(value: string): string {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

function parseMoney(text: string): number | null {
  const match = text.match(/(?:a partir de|à partir de|tarif(?: de)?|pack(?: a| à)?|prix(?: de)?)?\s*(\d{1,4}(?:[,.]\d{1,2})?)\s*€/i);
  if (!match) return null;
  const value = Number(match[1].replace(',', '.'));
  return Number.isFinite(value) ? value : null;
}

function parsePercent(text: string): number | null {
  const match = text.match(/(?:-|jusqu['’]a\s*-?|remise(?: de)?\s*)(\d{1,2}(?:[,.]\d)?)\s*%/i);
  if (!match) return null;
  const value = Number(match[1].replace(',', '.'));
  return Number.isFinite(value) ? value : null;
}

function toIsoDate(day: number, month: number, year: number): string | null {
  if (year < 2024 || year > 2035 || month < 1 || month > 12 || day < 1 || day > 31) return null;
  return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function parseDates(text: string): { startsAt: string | null; endsAt: string | null } {
  const dates: string[] = [];
  for (const match of text.matchAll(/\b(\d{1,2})[/.\-](\d{1,2})[/.\-](20\d{2})\b/g)) {
    const iso = toIsoDate(Number(match[1]), Number(match[2]), Number(match[3]));
    if (iso) dates.push(iso);
  }
  for (const match of text.matchAll(/\b(\d{1,2})\s+(janvier|f[eé]vrier|mars|avril|mai|juin|juillet|ao[uû]t|septembre|octobre|novembre|d[eé]cembre)\s+(20\d{2})\b/gi)) {
    const month = MONTHS[match[2].toLowerCase()] ?? 0;
    const iso = toIsoDate(Number(match[1]), month, Number(match[3]));
    if (iso) dates.push(iso);
  }
  dates.sort();
  if (dates.length === 0) return { startsAt: null, endsAt: null };
  if (dates.length === 1) {
    const lower = normalizeToken(text);
    return lower.includes('jusqu') || lower.includes('valable au') || lower.includes('fin')
      ? { startsAt: null, endsAt: dates[0] }
      : { startsAt: dates[0], endsAt: null };
  }
  return { startsAt: dates[0], endsAt: dates[dates.length - 1] };
}

function offerContextFor(text: string): 'CURRENT_VEHICLE' | 'VEHICLE_PURCHASE' {
  const value = normalizeToken(text);
  const explicitPurchase = /location longue duree|\blld\b|location avec option d achat|\bloa\b|premier loyer|1er loyer|apport|credit auto|financement vehicule|offre de reprise|prime reprise|reprise de votre vehicule|vehicule neuf|voiture neuve|vehicule d occasion|voiture d occasion|commandez votre|a l achat d un vehicule/.test(value);
  return explicitPurchase ? 'VEHICLE_PURCHASE' : 'CURRENT_VEHICLE';
}

function categoryFor(text: string, offerContext: 'CURRENT_VEHICLE' | 'VEHICLE_PURCHASE'): string {
  const value = normalizeToken(text);
  if (offerContext === 'VEHICLE_PURCHASE') {
    if (/occasion|vehicule d occasion|voiture d occasion/.test(value)) return 'USED_VEHICLE';
    return 'NEW_VEHICLE';
  }
  if (/controle technique|pre controle|inspection|bilan securite/.test(value)) return 'INSPECTION';
  if (/pneu|pneumatique|roue complete/.test(value)) return 'TYRES';
  if (/pare brise|pare-brise|vitrage|bris de glace/.test(value)) return 'WINDSCREEN';
  if (/climatisation|clim|recharge de gaz/.test(value)) return 'CLIMATE';
  if (/batterie/.test(value)) return 'BATTERY';
  if (/carrosserie|debosselage|peinture/.test(value)) return 'BODYWORK';
  if (/accessoire/.test(value)) return 'ACCESSORIES';
  if (/contrat d entretien|contrat entretien/.test(value)) return 'CONTRACT';
  if (/assistance|depannage/.test(value)) return 'ASSISTANCE';
  return 'MAINTENANCE';
}

function fuelTypesFor(text: string): string[] {
  const value = normalizeToken(text);
  const fuels: string[] = [];
  if (/electrique|\bev\b/.test(value)) fuels.push('electric');
  if (/hybride rechargeable|plug in|phev/.test(value)) fuels.push('plug_in_hybrid');
  else if (/hybride/.test(value)) fuels.push('hybrid');
  if (/essence|\btsi\b|\btfsi\b/.test(value)) fuels.push('petrol');
  if (/diesel|\btdi\b|\bdci\b|bluehdi/.test(value)) fuels.push('diesel');
  return [...new Set(fuels)];
}

function extractAge(text: string): { ageMin: number | null; ageMax: number | null } {
  const value = normalizeToken(text);
  const min = value.match(/(?:plus de|au moins)\s*(\d{1,2})\s*ans?/);
  const max = value.match(/(?:moins de|jusqu a)\s*(\d{1,2})\s*ans?/);
  return { ageMin: min ? Number(min[1]) : null, ageMax: max ? Number(max[1]) : null };
}

function extractMileage(text: string): { mileageMin: number | null; mileageMax: number | null } {
  const value = normalizeToken(text).replace(/\s/g, '');
  const max = value.match(/(?:moinsde|jusqua|maximum)(\d{2,6})km/);
  const min = value.match(/(?:plusde|minimum)(\d{2,6})km/);
  return { mileageMin: min ? Number(min[1]) : null, mileageMax: max ? Number(max[1]) : null };
}

function titleFromSegment(segment: string, benefitLabel: string): string {
  const lines = segment.split(/\n+/).map((line) => line.trim()).filter(Boolean);
  for (const line of lines) {
    if (line.length >= 4 && line.length <= 100 && /[a-zà-ÿ]/i.test(line)) return line.replace(/[.。]+$/, '');
  }
  return benefitLabel || 'Offre après-vente';
}

function candidateSegments(text: string): string[] {
  const lines = text.split(/\n+/).map((line) => line.trim()).filter(Boolean);
  const segments: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const window = lines.slice(Math.max(0, i - 1), Math.min(lines.length, i + 5)).join('\n');
    const normalized = normalizeToken(window);
    const hasBenefit = /\d{1,4}(?:[,.]\d{1,2})?\s*€|\d{1,2}\s*%|offert|gratuit|remise|promotion|a partir de|à partir de/.test(normalized);
    const hasVehicleContext = /entretien|revision|controle|pneu|pare brise|carrosserie|climatisation|frein|amortisseur|accessoire|atelier|service|vehicule|voiture|location longue duree|\blld\b|\bloa\b|loyer|apport|reprise|occasion|neuf/.test(normalized);
    if (hasBenefit && hasVehicleContext) segments.push(window.slice(0, 1800));
  }
  return [...new Set(segments)].slice(0, 40);
}

export function extractOffersFromHtml(html: string, source: OfferSource): ExtractedOffer[] {
  const visibleText = htmlToText(html);
  const embeddedText = embeddedDataToText(html);
  const text = `${visibleText}\n${embeddedText}`.trim();
  const offers: ExtractedOffer[] = [];
  for (const segment of candidateSegments(text)) {
    const normalized = normalizeToken(segment);
    const percent = parsePercent(segment);
    const money = parseMoney(segment);
    const free = /offert|gratuite?|sans frais/.test(normalized);
    if (percent === null && money === null && !free) continue;

    const benefitKind = percent !== null ? 'PERCENT' : 'FIXED_PRICE';
    const benefitValue = percent;
    const priceAmount = money ?? (free ? 0 : null);
    const benefitLabel = percent !== null ? `-${percent} %` : money !== null ? `${money.toFixed(money % 1 === 0 ? 0 : 2)} €` : 'Offert';
    const dates = parseDates(segment);
    const ages = extractAge(segment);
    const mileage = extractMileage(segment);
    const network = /r[eé]seau.{0,60}participant|point de vente.{0,40}participant|atelier.{0,40}participant/i.test(segment);
    const contract = /contrat d['’ ]entretien|contrat valide|souscription/.test(segment.toLowerCase());
    const title = titleFromSegment(segment, benefitLabel);
    const offerContext = offerContextFor(segment);
    const fuelTypes = fuelTypesFor(segment);
    let confidence = source.official ? 0.48 : 0.34;
    if (percent !== null || money !== null) confidence += 0.20;
    if (dates.endsAt) confidence += 0.10;
    if (/offre|valable|beneficiez|bénéficiez|profitez/.test(segment.toLowerCase())) confidence += 0.10;
    if (network || contract || ages.ageMin !== null || ages.ageMax !== null) confidence += 0.07;
    confidence = Math.min(0.98, confidence);

    const markerBase = [benefitLabel, dates.endsAt ?? '', network ? 'réseau participant' : '', contract ? 'contrat requis' : '']
      .filter(Boolean);
    const offerKey = `v4_${normalizeToken(source.brand).replace(/[^a-z0-9]+/g, '_')}_${hashText(normalizeToken(title + '|' + benefitLabel + '|' + (dates.endsAt ?? '')) )}`;
    offers.push({
      offerKey,
      title: title.slice(0, 180),
      summary: segment.replace(/\n+/g, ' ').slice(0, 700),
      category: categoryFor(segment, offerContext),
      offerContext,
      benefitKind,
      benefitLabel,
      benefitValue,
      priceAmount,
      startsAt: dates.startsAt,
      endsAt: dates.endsAt,
      modelPatterns: [],
      excludedModelPatterns: [],
      fuelTypes,
      excludedFuelTypes: [],
      yearMin: null,
      yearMax: null,
      ageMin: ages.ageMin,
      ageMax: ages.ageMax,
      mileageMin: mileage.mileageMin,
      mileageMax: mileage.mileageMax,
      conditionsSummary: network || contract ? segment.replace(/\n+/g, ' ').slice(0, 900) : 'Conditions détaillées à confirmer sur la source officielle.',
      eligibilityNotes: 'Compatibilité déterminée par la marque et les conditions explicitement détectées. Toute condition inconnue reste à confirmer.',
      requiresExistingContract: contract,
      requiresNetworkParticipation: network,
      requiresManualEligibility: true,
      validationMarkers: markerBase.slice(0, 8),
      confidence,
      rawExcerpt: segment.slice(0, 1200),
    });
  }
  const unique = new Map<string, ExtractedOffer>();
  for (const offer of offers) {
    const current = unique.get(offer.offerKey);
    if (!current || offer.confidence > current.confidence) unique.set(offer.offerKey, offer);
  }
  return [...unique.values()].sort((a, b) => b.confidence - a.confidence).slice(0, 12);
}
