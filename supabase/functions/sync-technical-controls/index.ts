import { createClient } from "npm:@supabase/supabase-js@2";

const API_BASE_URL =
  "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-controle-technique/records";

const PAGE_SIZE = 100;
const DEFAULT_MAX_PAGES = 5;
const ABSOLUTE_MAX_PAGES = 25;

const responseHeaders = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SyncRequest = {
  postal_prefix?: string;
  offset?: number;
  max_pages?: number;
  dry_run?: boolean;
};

type GovernmentRecord = {
  cct_siret?: unknown;
  cct_denomination?: unknown;
  cct_adresse?: unknown;
cct_code_postal?: unknown;
cct_commune?: unknown;
cct_tel?: unknown;
cct_url?: unknown;

  cat_vehicule_id?: unknown;
  cat_vehicule_libelle?: unknown;

  cat_energie_id?: unknown;
  cat_energie_libelle?: unknown;

  prix_visite?: unknown;
  prix_contre_visite_mini?: unknown;
  prix_contre_visite_maxi?: unknown;

  latitude?: unknown;
  longitude?: unknown;

  cct_update_date_time?: unknown;
};

type GovernmentResponse = {
  total_count?: number;
  results?: GovernmentRecord[];
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: responseHeaders,
  });
}

function normalizeText(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  const text = String(value).trim();

  return text.length > 0 ? text : null;
}

function normalizeRequiredText(
  value: unknown,
  fallback: string,
): string {
  return normalizeText(value) ?? fallback;
}

function normalizeSiret(value: unknown): string | null {
  const rawValue = normalizeText(value);

  if (!rawValue) {
    return null;
  }

  const digits = rawValue.replace(/\D/g, "");

  if (digits.length === 14) {
    return digits;
  }

  /*
   * Certains parseurs peuvent transformer un SIRET commençant par zéro
   * en nombre. Le remplissage permet de restaurer les zéros initiaux.
   */
  if (digits.length > 0 && digits.length < 14) {
    return digits.padStart(14, "0");
  }

  return null;
}

function normalizeIdentifier(value: unknown): string | null {
  const text = normalizeText(value);

  if (!text) {
    return null;
  }

  return text.substring(0, 100);
}

function normalizeNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }

  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }

  const normalizedValue = String(value)
    .trim()
    .replace(/\s/g, "")
    .replace(",", ".");

  const parsedValue = Number(normalizedValue);

  return Number.isFinite(parsedValue) ? parsedValue : null;
}

function normalizeCoordinate(
  value: unknown,
  minimum: number,
  maximum: number,
): number | null {
  const coordinate = normalizeNumber(value);

  if (
    coordinate === null ||
    coordinate < minimum ||
    coordinate > maximum
  ) {
    return null;
  }

  return coordinate;
}

function normalizeDate(value: unknown): string | null {
  const text = normalizeText(value);

  if (!text) {
    return null;
  }

  const date = new Date(text);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toISOString();
}

function validatePostalPrefix(value: unknown): string {
  const prefix = String(value ?? "").trim();

  /*
   * Deux chiffres pour la métropole.
   * Trois chiffres pour les départements ultramarins.
   */
  if (!/^\d{2,3}$/.test(prefix)) {
    throw new Error(
      "postal_prefix doit contenir deux ou trois chiffres, par exemple 21, 71 ou 971.",
    );
  }

  return prefix;
}

function validateOffset(value: unknown): number {
  const offset = Number(value ?? 0);

  if (!Number.isInteger(offset) || offset < 0 || offset > 9999) {
    throw new Error(
      "offset doit être un entier compris entre 0 et 9999.",
    );
  }

  return offset;
}

function validateMaxPages(value: unknown): number {
  const maxPages = Number(value ?? DEFAULT_MAX_PAGES);

  if (
    !Number.isInteger(maxPages) ||
    maxPages < 1 ||
    maxPages > ABSOLUTE_MAX_PAGES
  ) {
    throw new Error(
      `max_pages doit être compris entre 1 et ${ABSOLUTE_MAX_PAGES}.`,
    );
  }

  return maxPages;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: responseHeaders,
    });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      {
        success: false,
        error: "METHOD_NOT_ALLOWED",
        message: "Cette fonction accepte uniquement la méthode POST.",
      },
      405,
    );
  }

  const expectedSecret = Deno.env.get(
    "TECHNICAL_CONTROL_SYNC_SECRET",
  );

  if (!expectedSecret) {
    return jsonResponse(
      {
        success: false,
        error: "SERVER_CONFIGURATION_ERROR",
        message:
          "Le secret TECHNICAL_CONTROL_SYNC_SECRET est absent.",
      },
      500,
    );
  }

  const receivedSecret = request.headers.get("x-sync-secret");

  if (!receivedSecret || receivedSecret !== expectedSecret) {
    return jsonResponse(
      {
        success: false,
        error: "UNAUTHORIZED",
        message: "Secret de synchronisation absent ou incorrect.",
      },
      401,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get(
    "SUPABASE_SERVICE_ROLE_KEY",
  );

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      {
        success: false,
        error: "SERVER_CONFIGURATION_ERROR",
        message:
          "Les variables Supabase nécessaires sont absentes.",
      },
      500,
    );
  }

  const supabase = createClient(
    supabaseUrl,
    serviceRoleKey,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    },
  );

  let syncRunId: number | null = null;
  let postalPrefix = "";
  let currentOffset = 0;
  let maxPages = DEFAULT_MAX_PAGES;
  let dryRun = false;

  let totalCount = 0;
  let pagesProcessed = 0;
  let recordsRead = 0;
  let centersProcessed = 0;
  let pricesProcessed = 0;
  let skippedRecords = 0;

  try {
    let body: SyncRequest;

    try {
      body = await request.json();
    } catch {
      throw new Error("Le corps JSON de la requête est invalide.");
    }

    postalPrefix = validatePostalPrefix(body.postal_prefix);
    currentOffset = validateOffset(body.offset);
    maxPages = validateMaxPages(body.max_pages);
    dryRun = body.dry_run === true;

    if (!dryRun) {
      const { data: syncRun, error: syncRunError } =
        await supabase
          .from("technical_control_sync_runs")
          .insert({
            status: "RUNNING",
            technical_details: {
              postal_prefix: postalPrefix,
              initial_offset: currentOffset,
              max_pages: maxPages,
              dry_run: false,
            },
          })
          .select("id")
          .single();

      if (syncRunError) {
        throw new Error(
          `Impossible de créer le journal de synchronisation : ${syncRunError.message}`,
        );
      }

      syncRunId = Number(syncRun.id);
    }

    const initialOffset = currentOffset;

    for (
      let pageNumber = 0;
      pageNumber < maxPages;
      pageNumber += 1
    ) {
      const parameters = new URLSearchParams();

      parameters.set("limit", String(PAGE_SIZE));
      parameters.set("offset", String(currentOffset));

      parameters.set(
        "where",
        `startswith(cct_code_postal,'${postalPrefix}')`,
      );

      parameters.set(
  "order_by",
  [
    "cct_siret asc",
    "cat_vehicule_id asc",
    "cat_energie_id asc",
  ].join(", "),
);

      parameters.set(
        "select",
        [
          "cct_siret",
          "cct_denomination",
          "cct_adresse",
"cct_code_postal",
"cct_commune",
"cct_tel",
"cct_url",
"cat_vehicule_id",
          "cat_vehicule_libelle",
          "cat_energie_id",
          "cat_energie_libelle",
          "prix_visite",
          "prix_contre_visite_mini",
          "prix_contre_visite_maxi",
          "latitude",
          "longitude",
          "cct_update_date_time",
        ].join(","),
      );

      const apiUrl = `${API_BASE_URL}?${parameters.toString()}`;

      const apiResponse = await fetch(apiUrl, {
        method: "GET",
        headers: {
          Accept: "application/json",
          "User-Agent":
            "AutoClair-Technical-Control-Synchronizer/1.0",
        },
        signal: AbortSignal.timeout(45000),
      });

      if (!apiResponse.ok) {
        const responseText = await apiResponse.text();

        throw new Error(
          `L'API gouvernementale a répondu HTTP ${apiResponse.status}: ${responseText.substring(0, 500)}`,
        );
      }

      const governmentData =
        (await apiResponse.json()) as GovernmentResponse;

      const records = Array.isArray(governmentData.results)
        ? governmentData.results
        : [];

      totalCount = Number(governmentData.total_count ?? 0);

      if (totalCount > 10000) {
        throw new Error(
          `Le préfixe ${postalPrefix} retourne ${totalCount} lignes. Utilise un préfixe postal plus précis afin de rester sous la limite de 10 000 lignes.`,
        );
      }

      if (records.length === 0) {
        break;
      }

      const syncedAt = new Date().toISOString();

      const centersBySiret = new Map<
        string,
        Record<string, unknown>
      >();

      const pricesByKey = new Map<
        string,
        Record<string, unknown>
      >();

      for (const record of records) {
        const siret = normalizeSiret(record.cct_siret);
        const vehicleCategoryId = normalizeIdentifier(
          record.cat_vehicule_id,
        );
        const energyCategoryId = normalizeIdentifier(
          record.cat_energie_id,
        );

        if (
          !siret ||
          !vehicleCategoryId ||
          !energyCategoryId
        ) {
          skippedRecords += 1;
          continue;
        }

        const sourceUpdatedAt = normalizeDate(
          record.cct_update_date_time,
        );

        const latitude = normalizeCoordinate(
          record.latitude,
          -90,
          90,
        );

        const longitude = normalizeCoordinate(
          record.longitude,
          -180,
          180,
        );

        centersBySiret.set(siret, {
          siret,
          denomination: normalizeRequiredText(
            record.cct_denomination,
            "Centre de contrôle technique",
          ),
          address: normalizeText(record.cct_adresse),
postal_code: normalizeText(record.cct_code_postal),
city: normalizeText(record.cct_commune),
phone: normalizeText(record.cct_tel),
website: normalizeText(record.cct_url),
latitude,
longitude,
          is_active: true,
          source_updated_at: sourceUpdatedAt,
          last_synced_at: syncedAt,
        });

        const priceKey = [
          siret,
          vehicleCategoryId,
          energyCategoryId,
        ].join("|");

        pricesByKey.set(priceKey, {
          center_siret: siret,

          vehicle_category_id: vehicleCategoryId,
          vehicle_category_label: normalizeRequiredText(
            record.cat_vehicule_libelle,
            vehicleCategoryId,
          ),

          energy_category_id: energyCategoryId,
          energy_category_label: normalizeRequiredText(
            record.cat_energie_libelle,
            energyCategoryId,
          ),

          inspection_price: normalizeNumber(
            record.prix_visite,
          ),

          reinspection_min_price: normalizeNumber(
            record.prix_contre_visite_mini,
          ),

          reinspection_max_price: normalizeNumber(
            record.prix_contre_visite_maxi,
          ),

          source_updated_at: sourceUpdatedAt,
          last_synced_at: syncedAt,
        });
      }

      const centers = Array.from(centersBySiret.values());
      const prices = Array.from(pricesByKey.values());

      if (!dryRun && centers.length > 0) {
        const { error: centersError } = await supabase
          .from("technical_control_centers")
          .upsert(centers, {
            onConflict: "siret",
            ignoreDuplicates: false,
          });

        if (centersError) {
          throw new Error(
            `Erreur pendant l'enregistrement des centres : ${centersError.message}`,
          );
        }
      }

      if (!dryRun && prices.length > 0) {
        const { error: pricesError } = await supabase
          .from("technical_control_prices")
          .upsert(prices, {
            onConflict:
              "center_siret,vehicle_category_id,energy_category_id",
            ignoreDuplicates: false,
          });

        if (pricesError) {
          throw new Error(
            `Erreur pendant l'enregistrement des tarifs : ${pricesError.message}`,
          );
        }
      }

      recordsRead += records.length;
      centersProcessed += centers.length;
      pricesProcessed += prices.length;
      pagesProcessed += 1;
      currentOffset += records.length;

      if (
        records.length < PAGE_SIZE ||
        currentOffset >= totalCount
      ) {
        break;
      }
    }

    const hasMore =
      totalCount > 0 && currentOffset < totalCount;

    if (!dryRun && syncRunId !== null) {
      const { error: completionError } = await supabase
        .from("technical_control_sync_runs")
        .update({
          status: "SUCCESS",
          finished_at: new Date().toISOString(),
          source_record_count: recordsRead,
          center_count: centersProcessed,
          price_count: pricesProcessed,
          technical_details: {
            postal_prefix: postalPrefix,
            initial_offset: currentOffset - recordsRead,
            final_offset: currentOffset,
            max_pages: maxPages,
            pages_processed: pagesProcessed,
            skipped_records: skippedRecords,
            total_available_for_prefix: totalCount,
            has_more: hasMore,
          },
        })
        .eq("id", syncRunId);

      if (completionError) {
        throw new Error(
          `Les données ont été importées, mais le journal n'a pas pu être finalisé : ${completionError.message}`,
        );
      }
    }

    return jsonResponse({
      success: true,
      status: "SYNC_BATCH_COMPLETED",
      dry_run: dryRun,
      postal_prefix: postalPrefix,
      pages_processed: pagesProcessed,
      records_read: recordsRead,
      centers_processed: centersProcessed,
      prices_processed: pricesProcessed,
      skipped_records: skippedRecords,
      total_available_for_prefix: totalCount,
      next_offset: currentOffset,
      has_more: hasMore,
      sync_run_id: syncRunId,
      message: hasMore
        ? "Le lot a été importé. Une nouvelle exécution est nécessaire avec next_offset."
        : "Toutes les lignes du préfixe postal ont été importées.",
    });
  } catch (error) {
    const errorMessage = error instanceof Error
      ? error.message
      : String(error);

    if (syncRunId !== null) {
      await supabase
        .from("technical_control_sync_runs")
        .update({
          status: "FAILED",
          finished_at: new Date().toISOString(),
          source_record_count: recordsRead,
          center_count: centersProcessed,
          price_count: pricesProcessed,
          error_message: errorMessage,
          technical_details: {
            postal_prefix: postalPrefix,
            final_offset: currentOffset,
            max_pages: maxPages,
            pages_processed: pagesProcessed,
            skipped_records: skippedRecords,
          },
        })
        .eq("id", syncRunId);
    }

    console.error("Technical control synchronization failed", {
      error: errorMessage,
      postalPrefix,
      currentOffset,
      pagesProcessed,
    });

    return jsonResponse(
      {
        success: false,
        status: "SYNC_FAILED",
        error: errorMessage,
        postal_prefix: postalPrefix || null,
        next_offset: currentOffset,
        pages_processed: pagesProcessed,
        records_read: recordsRead,
        sync_run_id: syncRunId,
      },
      500,
    );
  }
});