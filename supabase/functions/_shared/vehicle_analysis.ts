import {
  asArray,
  asInteger,
  asNumber,
  asString,
  clamp,
  daysBetween,
  isRecord,
  isoDate,
  type JsonMap,
} from "./utils.ts";

export type SourceRecord = {
  source_id: string;
  source_type: string;
  source_label: string;
  source_date: string | null;
  confidence: "high" | "medium" | "low";
  payload: JsonMap;
};

export type DataQuality = {
  score: number;
  can_generate: boolean;
  missing: string[];
  warnings: string[];
  counts: Record<string, number>;
  detected: {
    brand: string | null;
    model: string | null;
    year: string | null;
    energy: string | null;
    mileage: number | null;
  };
};

function firstByKeys(
  object: JsonMap,
  aliases: string[],
): unknown {
  const lowered = new Map(
    Object.entries(object).map(([key, value]) => [key.toLowerCase(), value]),
  );

  for (const alias of aliases) {
    const value = lowered.get(alias.toLowerCase());
    if (value !== undefined && value !== null && value !== "") return value;
  }

  return null;
}

function latestMileage(datasets: JsonMap): number | null {
  const candidates: number[] = [];
  const rows = asArray(datasets.vehicle_odometer_readings);

  for (const row of rows) {
    if (!isRecord(row)) continue;
    const value = asInteger(
      firstByKeys(row, ["mileage", "odometer", "kilometrage", "value"]),
    );
    if (value !== null && value >= 0) candidates.push(value);
  }

  return candidates.length ? Math.max(...candidates) : null;
}

export function calculateDataQuality(snapshot: JsonMap): DataQuality {
  const vehicle = isRecord(snapshot.vehicle) ? snapshot.vehicle : {};
  const datasets = isRecord(snapshot.datasets) ? snapshot.datasets : {};

  const brand = asString(
    firstByKeys(vehicle, ["brand", "make", "marque", "manufacturer"]),
  );
  const model = asString(
    firstByKeys(vehicle, ["model", "model_name", "modele", "name"]),
  );
  const yearRaw = firstByKeys(vehicle, [
    "model_year",
    "vehicle_year",
    "year",
    "first_registration",
    "first_registration_date",
    "date_first_registration",
  ]);
  const year = asString(yearRaw) ??
    (asInteger(yearRaw) !== null ? String(asInteger(yearRaw)) : null);
  const energy = asString(
    firstByKeys(vehicle, [
      "energy",
      "fuel_type",
      "fuel",
      "motorization",
      "motorisation",
      "powertrain",
    ]),
  );
  const mileageFromVehicle = asInteger(
    firstByKeys(vehicle, [
      "current_mileage",
      "mileage",
      "odometer",
      "kilometrage",
    ]),
  );
  const mileage = mileageFromVehicle ?? latestMileage(datasets);

  const counts: Record<string, number> = {};
  for (const [name, value] of Object.entries(datasets)) {
    counts[name] = Array.isArray(value) ? value.length : 0;
  }

  let score = 0;
  const missing: string[] = [];
  const warnings: string[] = [];

  if (brand) score += 12;
  else missing.push("marque du vehicule");

  if (model) score += 12;
  else missing.push("modele du vehicule");

  if (year) score += 8;
  else missing.push("annee ou date de premiere mise en circulation");

  if (energy) score += 8;
  else missing.push("energie ou motorisation");

  if (mileage !== null) score += 15;
  else missing.push("kilometrage actuel");

  const eventCount =
    (counts.vehicle_events ?? 0) +
    (counts.vehicle_maintenance_schedules ?? 0);
  if (eventCount >= 5) score += 20;
  else if (eventCount >= 1) score += 10;
  else warnings.push("aucun entretien structure n'a ete trouve");

  const documentCount =
    (counts.vehicle_document_suggestions ?? 0) +
    (counts.documents ?? 0);
  if (documentCount >= 3) score += 15;
  else if (documentCount >= 1) score += 8;
  else warnings.push("aucun document exploitable n'a ete trouve");

  const expenseCount = counts.vehicle_expenses ?? 0;
  if (expenseCount >= 2) score += 5;

  const valuationCount = counts.vehicle_market_valuations ?? 0;
  if (valuationCount >= 1) score += 5;
  else warnings.push(
    "aucune cote de marche contractuelle n'est encore disponible",
  );

  score = clamp(score, 0, 100);

  return {
    score,
    can_generate: Boolean(brand && model && score >= 40),
    missing,
    warnings,
    counts,
    detected: {
      brand,
      model,
      year,
      energy,
      mileage,
    },
  };
}

function labelForRow(dataset: string, row: JsonMap): string {
  const value = firstByKeys(row, [
    "title",
    "label",
    "name",
    "description",
    "event_type",
    "category",
    "document_type",
    "provider",
    "valuation_type",
  ]);

  return asString(value) ?? dataset.replaceAll("_", " ");
}

function dateForRow(row: JsonMap): string | null {
  const value = firstByKeys(row, [
    "completed_at",
    "occurred_at",
    "event_date",
    "recorded_at",
    "valuation_date",
    "forecast_date",
    "due_date",
    "document_date",
    "created_at",
  ]);
  return isoDate(value);
}

const forbiddenAiKeys = new Set([
  "user_id",
  "raw_payload",
  "input_snapshot",
  "result_json",
  "payment_reference",
  "storage_path",
  "file_path",
  "file_url",
  "signed_url",
  "original_file_name",
  "extracted_text",
  "ocr_text",
  "analysis_result",
  "vin",
  "license_plate",
  "licence_plate",
  "registration_number",
  "registration",
]);

function sanitizeValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.slice(0, 100).map(sanitizeValue);
  }

  if (isRecord(value)) {
    const result: JsonMap = {};
    for (const [key, child] of Object.entries(value)) {
      if (forbiddenAiKeys.has(key.toLowerCase())) continue;
      result[key] = sanitizeValue(child);
    }
    return result;
  }

  if (typeof value === "string" && value.length > 1200) {
    return `${value.slice(0, 1200)}…`;
  }

  return value;
}

function sanitizeRow(row: JsonMap): JsonMap {
  return sanitizeValue(row) as JsonMap;
}

export function buildAiInput(
  snapshot: JsonMap,
  quality: DataQuality,
): {
  compactSnapshot: JsonMap;
  sources: SourceRecord[];
} {
  const vehicle = isRecord(snapshot.vehicle) ? snapshot.vehicle : {};
  const datasets = isRecord(snapshot.datasets) ? snapshot.datasets : {};
  const derived = isRecord(snapshot.derived) ? snapshot.derived : {};

  const sources: SourceRecord[] = [{
    source_id: `vehicle:${asString(snapshot.vehicle_id) ?? "unknown"}`,
    source_type: "vehicle",
    source_label: [
      quality.detected.brand,
      quality.detected.model,
      quality.detected.year,
    ].filter(Boolean).join(" "),
    source_date: null,
    confidence: "high",
    payload: sanitizeRow(vehicle),
  }];

  const aiDatasets: JsonMap = {};

  for (const [dataset, value] of Object.entries(datasets)) {
    const rows = asArray(value);
    const limited = rows.slice(0, 80);
    const enriched: JsonMap[] = [];

    for (let index = 0; index < limited.length; index += 1) {
      const raw = limited[index];
      if (!isRecord(raw)) continue;

      const row = sanitizeRow(raw);
      const rawId = asString(row.id) ?? String(index + 1);
      const sourceId = `${dataset}:${rawId}`;
      const source: SourceRecord = {
        source_id: sourceId,
        source_type: dataset,
        source_label: labelForRow(dataset, row),
        source_date: dateForRow(row),
        confidence: dataset === "vehicle_document_suggestions"
          ? "medium"
          : "high",
        payload: row,
      };
      sources.push(source);
      enriched.push({ ...row, _source_id: sourceId });
    }

    aiDatasets[dataset] = enriched;
  }

  return {
    compactSnapshot: {
      snapshot_version: snapshot.snapshot_version,
      vehicle: {
        ...sanitizeRow(vehicle),
        _source_id: sources[0].source_id,
      },
      datasets: aiDatasets,
      derived: sanitizeValue(derived),
      data_quality: quality,
      source_catalog: sources.map((source) => ({
        source_id: source.source_id,
        source_type: source.source_type,
        source_label: source.source_label,
        source_date: source.source_date,
        confidence: source.confidence,
      })),
    },
    sources,
  };
}

type Valuation = JsonMap & {
  valuation_date?: unknown;
  valuation_type?: unknown;
  value_low_eur?: unknown;
  value_mid_eur?: unknown;
  value_high_eur?: unknown;
  provider?: unknown;
  confidence_score?: unknown;
};

function sortedValuations(rows: unknown[]): Valuation[] {
  return rows
    .filter(isRecord)
    .map((row) => row as Valuation)
    .filter((row) => isoDate(row.valuation_date) !== null)
    .sort((a, b) =>
      String(isoDate(b.valuation_date)).localeCompare(
        String(isoDate(a.valuation_date)),
      )
    );
}

function latestOfType(
  rows: Valuation[],
  types: string[],
): Valuation | null {
  return rows.find((row) =>
    types.includes(asString(row.valuation_type) ?? "")
  ) ?? null;
}

function valuationView(row: Valuation | null): JsonMap | null {
  if (!row) return null;

  return {
    valuation_date: isoDate(row.valuation_date),
    provider: asString(row.provider),
    valuation_type: asString(row.valuation_type),
    value_low_eur: asNumber(row.value_low_eur),
    value_mid_eur: asNumber(row.value_mid_eur),
    value_high_eur: asNumber(row.value_high_eur),
    confidence_score: asNumber(row.confidence_score),
  };
}

export type SaleScenario = {
  scenario_code:
    | "sell_private_now"
    | "trade_in_now"
    | "prepare_then_sell"
    | "keep_12_months";
  expected_sale_value_eur: number | null;
  required_costs_eur: number | null;
  holding_costs_eur: number | null;
  expected_net_value_eur: number | null;
  estimated_delay_days: number | null;
  confidence_score: number | null;
  explanation: string;
  details: JsonMap;
};

export function buildMarketAndSaleAnalysis(
  snapshot: JsonMap,
  quality: DataQuality,
): {
  marketData: JsonMap;
  timing: JsonMap;
  scenarios: SaleScenario[];
} {
  const datasets = isRecord(snapshot.datasets) ? snapshot.datasets : {};
  const valuations = sortedValuations(
    asArray(datasets.vehicle_market_valuations),
  );
  const forecasts = asArray(datasets.vehicle_value_forecasts)
    .filter(isRecord)
    .map((row) => row as JsonMap);

  const privateValue = latestOfType(valuations, [
    "private_sale",
    "professional_retail",
    "market",
  ]);
  const tradeValue = latestOfType(valuations, ["trade_in", "b2b"]);

  const history = valuations
    .filter((row) =>
      ["private_sale", "professional_retail", "market"].includes(
        asString(row.valuation_type) ?? "",
      )
    )
    .slice()
    .reverse()
    .map(valuationView)
    .filter(Boolean);

  const forecastViews = forecasts
    .map((row) => ({
      forecast_date: isoDate(row.forecast_date),
      horizon_months: asInteger(row.horizon_months),
      scenario: asString(row.scenario),
      value_eur: asNumber(row.value_eur),
      confidence_score: asNumber(row.confidence_score),
      method: asString(row.method),
    }))
    .filter((row) => row.forecast_date && row.value_eur !== null)
    .sort((a, b) =>
      String(a.forecast_date).localeCompare(String(b.forecast_date))
    );

  const currentMid = asNumber(privateValue?.value_mid_eur);
  const tradeMid = asNumber(tradeValue?.value_mid_eur);
  const central12 = forecastViews.find((row) =>
    row.scenario === "central" && row.horizon_months === 12
  ) ?? null;

  const projected12 = central12?.value_eur ?? null;
  const depreciationRate = currentMid && projected12
    ? (currentMid - projected12) / currentMid
    : null;

  let timingStatus = "data_insufficient";
  let timingScore = 0;
  const reasons: string[] = [];

  if (currentMid === null) {
    reasons.push("aucune cote de marche contractuelle disponible");
  } else if (quality.score < 70) {
    timingStatus = "prepare_then_sell";
    timingScore = 55;
    reasons.push("le dossier doit etre complete avant une decision de vente");
  } else if (depreciationRate !== null && depreciationRate >= 0.08) {
    timingStatus = "compare_now";
    timingScore = 75;
    reasons.push(
      "la projection centrale indique une baisse sensible sur douze mois",
    );
  } else {
    timingStatus = "monitor";
    timingScore = 60;
    reasons.push(
      "aucun signal chiffre ne justifie a lui seul une vente immediate",
    );
  }

  const scenarios: SaleScenario[] = [
    {
      scenario_code: "sell_private_now",
      expected_sale_value_eur: currentMid,
      required_costs_eur: null,
      holding_costs_eur: null,
      expected_net_value_eur: null,
      estimated_delay_days: asInteger(privateValue?.estimated_days_to_sell),
      confidence_score: asNumber(privateValue?.confidence_score),
      explanation: currentMid === null
        ? "Scenario non chiffre : aucune cote particuliere contractuelle n'est disponible."
        : "Valeur centrale actuelle. Les frais de preparation et le prix final negocie ne sont pas inventes.",
      details: {
        valuation_type: asString(privateValue?.valuation_type),
        provider: asString(privateValue?.provider),
      },
    },
    {
      scenario_code: "trade_in_now",
      expected_sale_value_eur: tradeMid,
      required_costs_eur: null,
      holding_costs_eur: null,
      expected_net_value_eur: null,
      estimated_delay_days: tradeMid === null ? null : 1,
      confidence_score: asNumber(tradeValue?.confidence_score),
      explanation: tradeMid === null
        ? "Scenario non chiffre : aucune valeur de reprise contractuelle n'est disponible."
        : "Valeur centrale de reprise disponible. Les conditions commerciales restent a confirmer.",
      details: {
        valuation_type: asString(tradeValue?.valuation_type),
        provider: asString(tradeValue?.provider),
      },
    },
    {
      scenario_code: "prepare_then_sell",
      expected_sale_value_eur: currentMid,
      required_costs_eur: null,
      holding_costs_eur: null,
      expected_net_value_eur: null,
      estimated_delay_days: null,
      confidence_score: currentMid === null ? null : quality.score,
      explanation:
        "AutoClair liste les actions de preparation mais n'invente ni leur cout ni une hausse garantie du prix de vente.",
      details: {
        data_quality_score: quality.score,
      },
    },
    {
      scenario_code: "keep_12_months",
      expected_sale_value_eur: projected12,
      required_costs_eur: null,
      holding_costs_eur: null,
      expected_net_value_eur: null,
      estimated_delay_days: null,
      confidence_score: central12?.confidence_score ?? null,
      explanation: projected12 === null
        ? "Scenario non chiffre : aucune projection contractuelle a douze mois n'est disponible."
        : "Projection centrale a douze mois. Les couts de conservation restent separes tant qu'ils ne sont pas connus.",
      details: {
        forecast_method: central12?.method ?? null,
        projected_depreciation_rate: depreciationRate,
      },
    },
  ];

  const latestDate = isoDate(privateValue?.valuation_date);
  const freshnessDays = latestDate ? daysBetween(latestDate) : null;

  return {
    marketData: {
      available: currentMid !== null || tradeMid !== null,
      private_sale: valuationView(privateValue),
      trade_in: valuationView(tradeValue),
      history,
      forecasts: forecastViews,
      freshness_days: freshnessDays,
      disclaimer:
        "Estimation de marche et non prix de vente garanti. Les donnees proviennent exclusivement d'une source contractuelle ou d'un cache AutoClair.",
    },
    timing: {
      status: timingStatus,
      score: timingScore,
      reasons,
      projected_12_month_depreciation_rate: depreciationRate,
    },
    scenarios,
  };
}

export function filterInvalidSourceIds(
  value: unknown,
  allowed: Set<string>,
): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => filterInvalidSourceIds(item, allowed));
  }

  if (!isRecord(value)) return value;

  const result: JsonMap = {};
  for (const [key, item] of Object.entries(value)) {
    if (key === "source_ids" && Array.isArray(item)) {
      result[key] = item
        .filter((sourceId) =>
          typeof sourceId === "string" && allowed.has(sourceId)
        )
        .slice(0, 12);
    } else {
      result[key] = filterInvalidSourceIds(item, allowed);
    }
  }

  return result;
}

export function collectUsedSourceIds(value: unknown): Set<string> {
  const result = new Set<string>();

  function visit(item: unknown): void {
    if (Array.isArray(item)) {
      for (const child of item) visit(child);
      return;
    }

    if (!isRecord(item)) return;

    for (const [key, child] of Object.entries(item)) {
      if (key === "source_ids" && Array.isArray(child)) {
        for (const sourceId of child) {
          if (typeof sourceId === "string") result.add(sourceId);
        }
      } else {
        visit(child);
      }
    }
  }

  visit(value);
  return result;
}
