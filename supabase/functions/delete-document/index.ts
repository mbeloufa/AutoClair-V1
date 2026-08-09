import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET_ID = "vehicle-documents";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonRecord = Record<string, unknown>;

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

function requireUuid(value: unknown): string {
  if (typeof value !== "string") {
    throw new AppError(
      400,
      "DOCUMENT_ID_REQUIRED",
      "L'identifiant du document est obligatoire.",
    );
  }

  const normalized = value.trim().toLowerCase();
  const uuidPattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

  if (!uuidPattern.test(normalized)) {
    throw new AppError(
      400,
      "DOCUMENT_ID_INVALID",
      "L'identifiant du document est invalide.",
    );
  }

  return normalized;
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

    let requestBody: JsonRecord;

    try {
      requestBody = (await req.json()) as JsonRecord;
    } catch {
      throw new AppError(
        400,
        "REQUEST_BODY_INVALID",
        "Le contenu de la requête est invalide.",
      );
    }

    const documentId = requireUuid(requestBody.document_id);

    const { data: document, error: documentError } =
      await adminClient
        .from("documents")
        .select("id,user_id,status")
        .eq("id", documentId)
        .eq("user_id", user.id)
        .maybeSingle();

    if (documentError) {
      throw new AppError(
        500,
        "DOCUMENT_READ_FAILED",
        "Le document n'a pas pu être chargé.",
        documentError,
      );
    }

    if (!document) {
      throw new AppError(
        404,
        "DOCUMENT_NOT_FOUND",
        "Ce document n'existe pas ou ne vous appartient pas.",
      );
    }

    if (document.status === "processing") {
      throw new AppError(
        409,
        "DOCUMENT_ANALYSIS_PROCESSING",
        "Ce document ne peut pas être supprimé pendant son analyse.",
      );
    }

    const { data: filesData, error: filesError } =
      await adminClient
        .from("document_files")
        .select("object_path")
        .eq("document_id", documentId)
        .eq("user_id", user.id);

    if (filesError) {
      throw new AppError(
        500,
        "DOCUMENT_FILES_READ_FAILED",
        "Les fichiers associés n'ont pas pu être chargés.",
        filesError,
      );
    }

    const objectPaths = (filesData ?? [])
      .map((item) => item.object_path?.toString().trim())
      .filter(
        (path): path is string =>
          typeof path === "string" && path.length > 0,
      );

    if (objectPaths.length > 0) {
      const { error: storageError } =
        await adminClient.storage
          .from(BUCKET_ID)
          .remove(objectPaths);

      if (storageError) {
        throw new AppError(
          500,
          "DOCUMENT_STORAGE_DELETE_FAILED",
          "Le fichier privé n'a pas pu être supprimé.",
          storageError,
        );
      }
    }

    const { error: deleteError } = await adminClient
      .from("documents")
      .delete()
      .eq("id", documentId)
      .eq("user_id", user.id);

    if (deleteError) {
      throw new AppError(
        500,
        "DOCUMENT_DATABASE_DELETE_FAILED",
        "Les données du document n'ont pas pu être supprimées.",
        deleteError,
      );
    }

    return jsonResponse({
      success: true,
      document_id: documentId,
      deleted_files_count: objectPaths.length,
    });
  } catch (error) {
    const appError =
      error instanceof AppError
        ? error
        : new AppError(
            500,
            "UNEXPECTED_ERROR",
            "Une erreur inattendue est survenue pendant la suppression.",
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
