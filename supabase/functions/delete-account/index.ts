import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET_ID = "vehicle-documents";
const REQUIRED_CONFIRMATION = "SUPPRIMER MON COMPTE";
const LIST_PAGE_SIZE = 100;
const REMOVE_BATCH_SIZE = 100;
const MAX_DISCOVERED_OBJECTS = 10000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonRecord = Record<string, unknown>;

type StorageListItem = {
  id: string | null;
  name: string;
};

class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly internalDetails?: unknown,
  ) {
    super(message);
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function requireEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();

  if (!value) {
    throw new AppError(
      500,
      "SERVER_CONFIGURATION_ERROR",
      `Configuration serveur manquante : ${name}.`,
    );
  }

  return value;
}

function extractBearerToken(req: Request): string {
  const header = req.headers.get("Authorization")?.trim();

  if (!header?.startsWith("Bearer ")) {
    throw new AppError(
      401,
      "AUTH_REQUIRED",
      "Une session utilisateur valide est nécessaire.",
    );
  }

  const token = header.slice("Bearer ".length).trim();

  if (!token) {
    throw new AppError(
      401,
      "AUTH_REQUIRED",
      "Une session utilisateur valide est nécessaire.",
    );
  }

  return token;
}

function normalizedText(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function joinPath(parent: string, child: string): string {
  return parent ? `${parent}/${child}` : child;
}

async function listAllObjectsRecursively(
  adminClient: ReturnType<typeof createClient>,
  rootPath: string,
): Promise<string[]> {
  const discoveredFiles: string[] = [];
  const pendingFolders: string[] = [rootPath];

  while (pendingFolders.length > 0) {
    const folderPath = pendingFolders.shift()!;
    let offset = 0;

    while (true) {
      const { data, error } = await adminClient.storage
        .from(BUCKET_ID)
        .list(folderPath, {
          limit: LIST_PAGE_SIZE,
          offset,
          sortBy: {
            column: "name",
            order: "asc",
          },
        });

      if (error) {
        throw new AppError(
          500,
          "ACCOUNT_STORAGE_LIST_FAILED",
          "Les fichiers privés du compte n'ont pas pu être inventoriés.",
          error,
        );
      }

      const items = (data ?? []) as StorageListItem[];

      for (const item of items) {
        const itemPath = joinPath(folderPath, item.name);

        if (item.id === null) {
          pendingFolders.push(itemPath);
        } else {
          discoveredFiles.push(itemPath);
        }

        if (
          discoveredFiles.length + pendingFolders.length >
          MAX_DISCOVERED_OBJECTS
        ) {
          throw new AppError(
            413,
            "ACCOUNT_STORAGE_LIMIT_EXCEEDED",
            "Le compte contient trop de fichiers pour être supprimé en une seule opération.",
          );
        }
      }

      if (items.length < LIST_PAGE_SIZE) {
        break;
      }

      offset += LIST_PAGE_SIZE;
    }
  }

  return discoveredFiles;
}

async function deleteStorageObjects(
  adminClient: ReturnType<typeof createClient>,
  objectPaths: string[],
): Promise<number> {
  let deletedCount = 0;

  for (
    let offset = 0;
    offset < objectPaths.length;
    offset += REMOVE_BATCH_SIZE
  ) {
    const batch = objectPaths.slice(
      offset,
      offset + REMOVE_BATCH_SIZE,
    );

    const { data, error } = await adminClient.storage
      .from(BUCKET_ID)
      .remove(batch);

    if (error) {
      throw new AppError(
        500,
        "ACCOUNT_STORAGE_DELETE_FAILED",
        "Les fichiers privés du compte n'ont pas tous pu être supprimés.",
        error,
      );
    }

    deletedCount += data?.length ?? batch.length;
  }

  return deletedCount;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      {
        success: false,
        error_code: "METHOD_NOT_ALLOWED",
        message: "Utilisez une requête POST.",
      },
      405,
    );
  }

  try {
    const supabaseUrl = requireEnvironment("SUPABASE_URL");
    const serviceRoleKey = requireEnvironment(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

    const adminClient = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    const token = extractBearerToken(req);

    const {
      data: { user },
      error: userError,
    } = await adminClient.auth.getUser(token);

    if (userError || !user) {
      throw new AppError(
        401,
        "AUTH_INVALID",
        "Votre session a expiré. Reconnectez-vous.",
        userError,
      );
    }

    let body: JsonRecord;

    try {
      body = (await req.json()) as JsonRecord;
    } catch {
      throw new AppError(
        400,
        "REQUEST_BODY_INVALID",
        "Le contenu de la requête est invalide.",
      );
    }

    const confirmation = normalizedText(body.confirmation);
    const confirmedEmail = normalizedText(body.email).toLowerCase();
    const authenticatedEmail = user.email?.trim().toLowerCase() ?? "";

    if (confirmation !== REQUIRED_CONFIRMATION) {
      throw new AppError(
        400,
        "ACCOUNT_CONFIRMATION_INVALID",
        `Saisissez exactement « ${REQUIRED_CONFIRMATION} ».`,
      );
    }

    if (
      !authenticatedEmail ||
      confirmedEmail !== authenticatedEmail
    ) {
      throw new AppError(
        400,
        "ACCOUNT_EMAIL_CONFIRMATION_INVALID",
        "L'adresse e-mail de confirmation ne correspond pas au compte connecté.",
      );
    }

    const { count: processingCount, error: processingError } =
      await adminClient
        .from("documents")
        .select("id", {
          count: "exact",
          head: true,
        })
        .eq("user_id", user.id)
        .eq("status", "processing");

    if (processingError) {
      throw new AppError(
        500,
        "ACCOUNT_PROCESSING_CHECK_FAILED",
        "L'état des analyses n'a pas pu être vérifié.",
        processingError,
      );
    }

    if ((processingCount ?? 0) > 0) {
      throw new AppError(
        409,
        "ACCOUNT_ANALYSIS_PROCESSING",
        "Le compte ne peut pas être supprimé pendant une analyse.",
      );
    }

    const knownPaths = new Set<string>();

    const { data: databaseFiles, error: databaseFilesError } =
      await adminClient
        .from("document_files")
        .select("object_path")
        .eq("user_id", user.id);

    if (databaseFilesError) {
      throw new AppError(
        500,
        "ACCOUNT_FILE_METADATA_READ_FAILED",
        "Les fichiers associés au compte n'ont pas pu être chargés.",
        databaseFilesError,
      );
    }

    for (const file of databaseFiles ?? []) {
      const objectPath = normalizedText(file.object_path);
      if (objectPath) {
        knownPaths.add(objectPath);
      }
    }

    const discoveredPaths = await listAllObjectsRecursively(
      adminClient,
      user.id,
    );

    for (const objectPath of discoveredPaths) {
      knownPaths.add(objectPath);
    }

    const objectPaths = [...knownPaths].sort();

    const deletedFilesCount = await deleteStorageObjects(
      adminClient,
      objectPaths,
    );

    const { error: deleteUserError } =
      await adminClient.auth.admin.deleteUser(
        user.id,
        false,
      );

    if (deleteUserError) {
      throw new AppError(
        500,
        "ACCOUNT_AUTH_DELETE_FAILED",
        "Le compte utilisateur n'a pas pu être supprimé. Réessayez.",
        deleteUserError,
      );
    }

    console.info(
      JSON.stringify({
        event: "account_deleted",
        deleted_files_count: deletedFilesCount,
      }),
    );

    return jsonResponse({
      success: true,
      deleted_files_count: deletedFilesCount,
    });
  } catch (error) {
    const appError =
      error instanceof AppError
        ? error
        : new AppError(
            500,
            "UNEXPECTED_ERROR",
            "Une erreur inattendue est survenue pendant la suppression du compte.",
            error,
          );

    console.error(
      JSON.stringify({
        error_code: appError.code,
        message: appError.message,
        internal_details: appError.internalDetails,
      }),
    );

    return jsonResponse(
      {
        success: false,
        error_code: appError.code,
        message: appError.message,
      },
      appError.status,
    );
  }
});
