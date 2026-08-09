import { createClient } from "npm:@supabase/supabase-js@2";

const API_URL =
  "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/rappelconso-v2-gtin-espaces/records";

const PAGE_SIZE = 100;
const DEFAULT_MAX_PAGES = 20;
const ABSOLUTE_MAX_PAGES = 30;

const headers = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SyncBody = {
  offset?: number;
  max_pages?: number;
  dry_run?: boolean;
};

type RecallRecord = Record<string, unknown>;

type RecallResponse = {
  total_count?: number;
  results?: RecallRecord[];
};

function response(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload, null, 2), { status, headers });
}

function text(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const normalized = String(value).trim();
  return normalized.length > 0 ? normalized : null;
}

function integer(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isInteger(parsed) ? parsed : null;
}

function isoDate(value: unknown): string | null {
  const raw = text(value);
  if (!raw) return null;
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function dateOnly(value: unknown): string | null {
  const raw = text(value);
  if (!raw) return null;
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString().slice(0, 10);
}

function normalize(value: unknown): string | null {
  const raw = text(value);
  if (!raw) return null;
  return raw
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function splitLinks(value: unknown): string[] {
  const raw = text(value);
  if (!raw) return [];
  return raw
    .split("|")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function validateOffset(value: unknown): number {
  const offset = Number(value ?? 0);
  if (!Number.isInteger(offset) || offset < 0 || offset > 9999) {
    throw new Error("offset doit être un entier compris entre 0 et 9999.");
  }
  return offset;
}

function validateMaxPages(value: unknown): number {
  const pages = Number(value ?? DEFAULT_MAX_PAGES);
  if (!Number.isInteger(pages) || pages < 1 || pages > ABSOLUTE_MAX_PAGES) {
    throw new Error(
      `max_pages doit être compris entre 1 et ${ABSOLUTE_MAX_PAGES}.`,
    );
  }
  return pages;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  if (request.method !== "POST") {
    return response(
      { success: false, error: "METHOD_NOT_ALLOWED" },
      405,
    );
  }

  const expectedSecret = Deno.env.get("VEHICLE_RECALL_SYNC_SECRET");
  if (!expectedSecret) {
    return response(
      {
        success: false,
        error: "SERVER_CONFIGURATION_ERROR",
        message: "Le secret VEHICLE_RECALL_SYNC_SECRET est absent.",
      },
      500,
    );
  }

  if (request.headers.get("x-sync-secret") !== expectedSecret) {
    return response(
      {
        success: false,
        error: "UNAUTHORIZED",
        message: "Secret de synchronisation absent ou incorrect.",
      },
      401,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return response(
      {
        success: false,
        error: "SERVER_CONFIGURATION_ERROR",
        message: "Les variables Supabase serveur sont absentes.",
      },
      500,
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let syncRunId: string | null = null;
  let offset = 0;
  let initialOffset = 0;
  let maxPages = DEFAULT_MAX_PAGES;
  let dryRun = false;
  let pagesProcessed = 0;
  let recordsRead = 0;
  let insertedCount = 0;
  let updatedCount = 0;
  let totalCount = 0;

  try {
    let body: SyncBody = {};
    try {
      body = (await request.json()) as SyncBody;
    } catch {
      body = {};
    }

    offset = validateOffset(body.offset);
    initialOffset = offset;
    maxPages = validateMaxPages(body.max_pages);
    dryRun = body.dry_run === true;

    if (!dryRun) {
      const { data, error } = await supabase
        .from("vehicle_sync_runs")
        .insert({
          source: "RAPPELCONSO_V2",
          status: "RUNNING",
          technical_details: {
            initial_offset: initialOffset,
            max_pages: maxPages,
          },
        })
        .select("id")
        .single();

      if (error) {
        throw new Error(`Journal de synchronisation : ${error.message}`);
      }
      syncRunId = String(data.id);
    }

    for (let page = 0; page < maxPages; page += 1) {
      const params = new URLSearchParams();
      params.set("limit", String(PAGE_SIZE));
      params.set("offset", String(offset));
      params.set(
        "where",
        'categorie_produit = "automobiles et moyens de déplacement" and sous_categorie_produit = "automobiles, motos, scooters"',
      );
      params.set("order_by", "date_publication desc, id desc");
      params.set(
        "select",
        [
          "date_publication",
          "numero_fiche",
          "numero_version",
          "categorie_produit",
          "sous_categorie_produit",
          "marque_produit",
          "modeles_ou_references",
          "date_debut_commercialisation",
          "date_date_fin_commercialisation",
          "motif_rappel",
          "risques_encourus",
          "conduites_a_tenir_par_le_consommateur",
          "numero_contact",
          "modalites_de_compensation",
          "date_de_fin_de_la_procedure_de_rappel",
          "liens_vers_les_images",
          "lien_vers_la_fiche_rappel",
          "rappel_guid",
          "libelle",
          "id",
        ].join(","),
      );

      const apiResponse = await fetch(`${API_URL}?${params.toString()}`, {
        headers: {
          Accept: "application/json",
          "User-Agent": "AutoClair-Vehicle-Recall-Synchronizer/1.0",
        },
        signal: AbortSignal.timeout(45_000),
      });

      if (!apiResponse.ok) {
        const details = await apiResponse.text();
        throw new Error(
          `RappelConso HTTP ${apiResponse.status}: ${details.slice(0, 600)}`,
        );
      }

      const apiData = (await apiResponse.json()) as RecallResponse;
      const records = Array.isArray(apiData.results) ? apiData.results : [];
      totalCount = Number(apiData.total_count ?? 0);

      if (records.length === 0) break;

      const rows = records.map((record) => {
        const sourceRecordId =
          text(record.id) ?? text(record.rappel_guid) ?? text(record.numero_fiche);
        if (!sourceRecordId) {
          throw new Error("Un rappel ne possède aucun identifiant exploitable.");
        }

        return {
          source: "RAPPELCONSO",
          source_record_id: sourceRecordId,
          source_guid: text(record.rappel_guid),
          fiche_number: text(record.numero_fiche),
          version_number: integer(record.numero_version),
          publication_date: isoDate(record.date_publication),
          category: text(record.categorie_produit),
          subcategory: text(record.sous_categorie_produit),
          brand: text(record.marque_produit),
          models_references: text(record.modeles_ou_references),
          title: text(record.libelle),
          recall_reason: text(record.motif_rappel),
          risks: text(record.risques_encourus),
          consumer_actions: text(
            record.conduites_a_tenir_par_le_consommateur,
          ),
          contact: text(record.numero_contact),
          compensation: text(record.modalites_de_compensation),
          commercialization_start: dateOnly(record.date_debut_commercialisation),
          commercialization_end: dateOnly(
            record.date_date_fin_commercialisation,
          ),
          procedure_end: dateOnly(record.date_de_fin_de_la_procedure_de_rappel),
          recall_url: text(record.lien_vers_la_fiche_rappel),
          image_urls: splitLinks(record.liens_vers_les_images),
          normalized_brand: normalize(record.marque_produit),
          normalized_models: normalize(record.modeles_ou_references),
          raw_payload: record,
          last_synced_at: new Date().toISOString(),
        };
      });

      if (!dryRun) {
        const ids = rows.map((row) => row.source_record_id);
        const { data: existing, error: existingError } = await supabase
          .from("official_vehicle_recalls")
          .select("source_record_id")
          .in("source_record_id", ids);

        if (existingError) {
          throw new Error(`Lecture des rappels existants : ${existingError.message}`);
        }

        const existingIds = new Set(
          (existing ?? []).map((item: Record<string, unknown>) => String(item.source_record_id)),
        );
        insertedCount += rows.filter(
          (row) => !existingIds.has(row.source_record_id),
        ).length;
        updatedCount += rows.filter((row) =>
          existingIds.has(row.source_record_id)
        ).length;

        const { error: upsertError } = await supabase
          .from("official_vehicle_recalls")
          .upsert(rows, {
            onConflict: "source_record_id",
            ignoreDuplicates: false,
          });

        if (upsertError) {
          throw new Error(`Enregistrement des rappels : ${upsertError.message}`);
        }
      }

      recordsRead += records.length;
      pagesProcessed += 1;
      offset += records.length;

      if (records.length < PAGE_SIZE || offset >= totalCount) break;
    }

    let matchedCount = 0;
    if (!dryRun) {
      const { data, error } = await supabase.rpc("match_all_vehicle_recalls");
      if (error) {
        throw new Error(`Rapprochement des véhicules : ${error.message}`);
      }
      matchedCount = Number(data ?? 0);
    }

    const hasMore = totalCount > 0 && offset < totalCount;

    if (!dryRun && syncRunId) {
      await supabase
        .from("vehicle_sync_runs")
        .update({
          status: hasMore ? "PARTIAL_SUCCESS" : "SUCCESS",
          finished_at: new Date().toISOString(),
          source_record_count: recordsRead,
          inserted_count: insertedCount,
          updated_count: updatedCount,
          matched_count: matchedCount,
          technical_details: {
            initial_offset: initialOffset,
            final_offset: offset,
            total_available: totalCount,
            pages_processed: pagesProcessed,
            has_more: hasMore,
          },
        })
        .eq("id", syncRunId);
    }

    return response({
      success: true,
      status: "SYNC_COMPLETED",
      dry_run: dryRun,
      pages_processed: pagesProcessed,
      records_read: recordsRead,
      inserted_count: insertedCount,
      updated_count: updatedCount,
      matched_count: matchedCount,
      total_available: totalCount,
      next_offset: offset,
      has_more: hasMore,
      sync_run_id: syncRunId,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    if (syncRunId) {
      await supabase
        .from("vehicle_sync_runs")
        .update({
          status: "FAILED",
          finished_at: new Date().toISOString(),
          source_record_count: recordsRead,
          inserted_count: insertedCount,
          updated_count: updatedCount,
          error_message: message,
          technical_details: {
            initial_offset: initialOffset,
            final_offset: offset,
            pages_processed: pagesProcessed,
          },
        })
        .eq("id", syncRunId);
    }

    console.error("Vehicle recall synchronization failed", {
      message,
      offset,
      pagesProcessed,
    });

    return response(
      {
        success: false,
        status: "SYNC_FAILED",
        error: message,
        next_offset: offset,
        pages_processed: pagesProcessed,
        records_read: recordsRead,
        sync_run_id: syncRunId,
      },
      500,
    );
  }
});