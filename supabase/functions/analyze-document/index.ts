import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET_ID = "vehicle-documents";
const PROMPT_VERSION = "autoclair-document-v2";
const SCHEMA_VERSION = "2.0";
const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonRecord = Record<string, unknown>;

type DocumentRow = {
  id: string;
  user_id: string;
  vehicle_id: string | null;
  document_type: string;
  comment: string | null;
  status: string;
};

type DocumentFileRow = {
  id: string;
  document_id: string;
  object_path: string;
  original_name: string;
  mime_type: string;
  size_bytes: number;
  page_order: number;
};

type VehicleRow = {
  id: string;
  nickname: string | null;
  make: string;
  model: string;
  vehicle_year: number | null;
  fuel_type: string | null;
  mileage: number | null;
  registration_number: string | null;
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

const ANALYSIS_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    document_type_detected: {
      type: "string",
      enum: [
        "estimate",
        "invoice",
        "repair_order",
        "technical_inspection_report",
        "unknown",
      ],
    },
    summary: { type: "string", minLength: 1, maxLength: 5000 },
    overall_confidence: { type: "number", minimum: 0, maximum: 1 },
    document_quality: {
      type: "object",
      additionalProperties: false,
      properties: {
        readability: { type: "string", enum: ["good", "partial", "poor"] },
        missing_or_unreadable_elements: {
          type: "array",
          items: { type: "string" },
        },
      },
      required: ["readability", "missing_or_unreadable_elements"],
    },
    parties: {
      type: "object",
      additionalProperties: false,
      properties: {
        garage_name: { type: ["string", "null"] },
      },
      required: ["garage_name"],
    },
    vehicle: {
      type: "object",
      additionalProperties: false,
      properties: {
        registration_number: { type: ["string", "null"] },
        vin: { type: ["string", "null"] },
        make: { type: ["string", "null"] },
        model: { type: ["string", "null"] },
        mileage: { type: ["number", "null"], minimum: 0 },
      },
      required: ["registration_number", "vin", "make", "model", "mileage"],
    },
    dates: {
      type: "object",
      additionalProperties: false,
      properties: {
        document_date: { type: ["string", "null"] },
        validity_end_date: { type: ["string", "null"] },
      },
      required: ["document_date", "validity_end_date"],
    },
    amounts: {
      type: "object",
      additionalProperties: false,
      properties: {
        currency: { type: "string" },
        subtotal_excluding_tax: { type: ["number", "null"] },
        tax_amount: { type: ["number", "null"] },
        total_including_tax: { type: ["number", "null"] },
      },
      required: [
        "currency",
        "subtotal_excluding_tax",
        "tax_amount",
        "total_including_tax",
      ],
    },
    facts: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          label: { type: "string" },
          value: { type: "string" },
          source: { type: "string" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
        },
        required: ["label", "value", "source", "confidence"],
      },
    },
    line_items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          description: { type: "string" },
          category: {
            type: "string",
            enum: ["parts", "labor", "fluids", "fees", "discount", "other"],
          },
          quantity: { type: ["number", "null"], minimum: 0 },
          unit_price_excluding_tax: { type: ["number", "null"], minimum: 0 },
          total_excluding_tax: { type: ["number", "null"] },
          necessity_assessment: {
            type: "string",
            enum: ["explicitly_required", "recommended", "optional", "unclear"],
          },
          explanation: { type: "string" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
        },
        required: [
          "description",
          "category",
          "quantity",
          "unit_price_excluding_tax",
          "total_excluding_tax",
          "necessity_assessment",
          "explanation",
          "confidence",
        ],
      },
    },
    technical_inspection: {
      type: "object",
      additionalProperties: false,
      properties: {
        result: {
          type: ["string", "null"],
          enum: [
            "favorable",
            "unfavorable_major",
            "unfavorable_critical",
            "unknown",
            null,
          ],
        },
        reinspection_required: { type: ["boolean", "null"] },
        reinspection_deadline: { type: ["string", "null"] },
        defects: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              severity: {
                type: "string",
                enum: ["critical", "major", "minor", "unknown"],
              },
              code: { type: ["string", "null"] },
              wording: { type: "string" },
              explanation: { type: "string" },
              recommended_action: { type: "string" },
              confidence: { type: "number", minimum: 0, maximum: 1 },
            },
            required: [
              "severity",
              "code",
              "wording",
              "explanation",
              "recommended_action",
              "confidence",
            ],
          },
        },
      },
      required: [
        "result",
        "reinspection_required",
        "reinspection_deadline",
        "defects",
      ],
    },
    observations: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          level: { type: "string", enum: ["information", "attention", "important"] },
          title: { type: "string" },
          explanation: { type: "string" },
          basis: { type: "string", enum: ["document_fact", "calculation", "inference"] },
          confidence: { type: "number", minimum: 0, maximum: 1 },
        },
        required: ["level", "title", "explanation", "basis", "confidence"],
      },
    },
    questions_to_ask: { type: "array", items: { type: "string" } },
    uncertainties: { type: "array", items: { type: "string" } },
    disclaimer: { type: "string", minLength: 1 },
  },
  required: [
    "document_type_detected",
    "summary",
    "overall_confidence",
    "document_quality",
    "parties",
    "vehicle",
    "dates",
    "amounts",
    "facts",
    "line_items",
    "technical_inspection",
    "observations",
    "questions_to_ask",
    "uncertainties",
    "disclaimer",
  ],
} as const;

const SYSTEM_PROMPT = `
Tu es AutoClair, un assistant pédagogique francophone spécialisé dans la
lecture de documents automobiles destinés aux particuliers.

Tu dois reconnaître autant que possible si le document est un devis, une
facture, un ordre de réparation ou un procès-verbal de contrôle technique.
Lorsque le type déclaré vaut "other", il s'agit d'une demande de détection
automatique : base-toi d'abord sur le contenu réel du document.

Règles impératives :
- Analyse uniquement ce qui est visible ou lisible dans les fichiers fournis.
- N'invente jamais une donnée absente.
- Distingue clairement les faits du document, les calculs et les inférences.
- Signale toute information incertaine, manquante ou illisible.
- Ne formule jamais d'accusation de fraude, d'arnaque, de tromperie ou de faute.
- Une incohérence doit être présentée comme un point à vérifier.
- N'affirme pas qu'une opération mécanique est indispensable si le document ne
  le démontre pas clairement.
- Ignore les données personnelles inutiles : ne restitue pas le nom, l'adresse,
  le téléphone ou l'e-mail d'un particulier.
- Le nom d'un professionnel automobile peut être conservé s'il aide à
  comprendre le document. N'extrais pas son adresse si elle n'est pas utile.
- Les explications doivent être compréhensibles par un particulier.
- Les montants sont des nombres, sans symbole monétaire.
- Utilise "EUR" comme devise lorsque le document indique des euros.
- Les dates doivent être au format AAAA-MM-JJ lorsque la date est lisible ;
  sinon utilise null.
- Réponds exclusivement en français et respecte strictement le schéma JSON.
- Le résultat ne remplace ni un diagnostic mécanique, ni un avis juridique,
  ni une expertise contradictoire.

Pour un contrôle technique :
- document_type_detected doit être "technical_inspection_report".
- Extrais le résultat global seulement s'il est lisible.
- Indique si une contre-visite est explicitement requise.
- Extrais son échéance uniquement si elle figure sur le document.
- Reprends chaque défaillance importante avec son niveau (critique, majeure,
  mineure ou inconnue), son libellé, une explication simple et l'action utile.
- Ne transforme jamais une défaillance mineure en urgence.
- technical_inspection.defects doit être vide si aucune défaillance n'est
  lisible.
- Pour les autres types de documents, technical_inspection doit contenir
  result=null, reinspection_required=null, reinspection_deadline=null et une
  liste defects vide.
`.trim();

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

function bytesToBase64(bytes: Uint8Array): string {
  const chunks: string[] = [];
  const chunkSize = 0x8000;

  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    const chunk = bytes.subarray(
      offset,
      Math.min(offset + chunkSize, bytes.length),
    );
    chunks.push(String.fromCharCode(...chunk));
  }

  return btoa(chunks.join(""));
}

function normalizeFileName(fileName: string): string {
  const cleaned = fileName
    .replace(/[\u0000-\u001f\u007f]/g, "")
    .trim();

  return cleaned || "document";
}

function buildUserContext(
  document: DocumentRow,
  vehicle: VehicleRow | null,
): string {
  const documentTypeLabel: Record<string, string> = {
    estimate: "devis",
    invoice: "facture",
    repair_order: "ordre de réparation",
    technical_inspection_report: "contrôle technique",
    other: "détection automatique / autre document",
  };

  const lines = [
    `Type déclaré par l'utilisateur : ${
      documentTypeLabel[document.document_type] ?? document.document_type
    }.`,
  ];

  if (document.comment?.trim()) {
    lines.push(`Commentaire de l'utilisateur : ${document.comment.trim()}`);
  }

  if (vehicle) {
    const vehicleParts = [
      vehicle.nickname?.trim() || null,
      `${vehicle.make} ${vehicle.model}`.trim(),
      vehicle.vehicle_year ? `année ${vehicle.vehicle_year}` : null,
      vehicle.fuel_type?.trim()
        ? `motorisation ${vehicle.fuel_type.trim()}`
        : null,
      vehicle.mileage !== null
        ? `kilométrage déclaré ${vehicle.mileage} km`
        : null,
      vehicle.registration_number?.trim()
        ? `immatriculation déclarée ${vehicle.registration_number.trim()}`
        : null,
    ].filter(Boolean);

    lines.push(
      `Véhicule enregistré dans AutoClair : ${vehicleParts.join(", ")}.`,
    );
  }

  lines.push(
    "Les données enregistrées dans AutoClair servent uniquement de contexte. " +
      "Toute différence avec le document doit être signalée comme un point à vérifier.",
  );

  return lines.join("\n");
}

function getOutputText(openAiResponse: JsonRecord): string {
  const output = openAiResponse.output;
  if (!Array.isArray(output)) {
    return "";
  }

  const texts: string[] = [];

  for (const item of output) {
    if (
      typeof item !== "object" ||
      item === null ||
      (item as JsonRecord).type !== "message"
    ) {
      continue;
    }

    const content = (item as JsonRecord).content;
    if (!Array.isArray(content)) {
      continue;
    }

    for (const part of content) {
      if (typeof part !== "object" || part === null) {
        continue;
      }

      const record = part as JsonRecord;

      if (record.type === "refusal" && typeof record.refusal === "string") {
        throw new AppError(
          422,
          "OPENAI_REFUSAL",
          "Le document n'a pas pu être analysé automatiquement.",
        );
      }

      if (record.type === "output_text" && typeof record.text === "string") {
        texts.push(record.text);
      }
    }
  }

  return texts.join("").trim();
}

function validateAnalysisResult(value: unknown): JsonRecord {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new AppError(
      502,
      "OPENAI_RESULT_INVALID",
      "Le résultat de l'analyse n'est pas exploitable.",
    );
  }

  const result = value as JsonRecord;

  if (
    typeof result.summary !== "string" ||
    result.summary.trim().length === 0 ||
    result.summary.length > 5000
  ) {
    throw new AppError(
      502,
      "OPENAI_RESULT_INVALID",
      "Le résumé produit par l'analyse est invalide.",
    );
  }

  if (
    typeof result.overall_confidence !== "number" ||
    !Number.isFinite(result.overall_confidence) ||
    result.overall_confidence < 0 ||
    result.overall_confidence > 1
  ) {
    throw new AppError(
      502,
      "OPENAI_RESULT_INVALID",
      "L'indice de confiance produit par l'analyse est invalide.",
    );
  }

  return result;
}

function mapOpenAiError(status: number, body: JsonRecord): AppError {
  const error = body.error;
  const errorRecord =
    typeof error === "object" && error !== null
      ? (error as JsonRecord)
      : {};

  const internalMessage =
    typeof errorRecord.message === "string"
      ? errorRecord.message
      : "Erreur OpenAI sans détail.";

  if (status === 401 || status === 403) {
    return new AppError(
      502,
      "OPENAI_AUTH_ERROR",
      "Le service d'analyse est temporairement indisponible.",
      internalMessage,
    );
  }

  if (status === 429) {
    return new AppError(
      429,
      "OPENAI_RATE_LIMIT",
      "Le service d'analyse est momentanément très sollicité. Réessayez plus tard.",
      internalMessage,
    );
  }

  if (status === 402) {
    return new AppError(
      503,
      "OPENAI_BILLING_ERROR",
      "Le service d'analyse n'est pas disponible pour le moment.",
      internalMessage,
    );
  }

  if (status >= 500) {
    return new AppError(
      503,
      "OPENAI_UNAVAILABLE",
      "Le service d'analyse est temporairement indisponible.",
      internalMessage,
    );
  }

  return new AppError(
    502,
    "OPENAI_REQUEST_FAILED",
    "Le document n'a pas pu être analysé.",
    internalMessage,
  );
}

async function markAnalysisFailed(
  adminClient: ReturnType<typeof createClient>,
  documentId: string,
  userId: string,
  errorCode: string,
): Promise<void> {
  try {
    await adminClient.rpc("fail_document_analysis", {
      p_document_id: documentId,
      p_user_id: userId,
      p_error_code: errorCode,
    });
  } catch (error) {
    console.error("Unable to mark analysis as failed", error);
  }
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

  let claimedDocumentId: string | null = null;
  let authenticatedUserId: string | null = null;
  let adminClient: ReturnType<typeof createClient> | null = null;

  try {
    const supabaseUrl = requireEnvironment("SUPABASE_URL");
    const serviceRoleKey = requireEnvironment(
      "SUPABASE_SERVICE_ROLE_KEY",
    );
    const openAiApiKey = requireEnvironment("OPENAI_API_KEY");
    const openAiModel = requireEnvironment("OPENAI_MODEL");

    adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

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

    authenticatedUserId = user.id;

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

    const { data: documentData, error: documentError } = await adminClient
      .from("documents")
      .select(
        "id,user_id,vehicle_id,document_type,comment,status",
      )
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

    if (!documentData) {
      throw new AppError(
        404,
        "DOCUMENT_NOT_FOUND",
        "Ce document n'existe pas ou ne vous appartient pas.",
      );
    }

    const document = documentData as DocumentRow;

    const { data: claimState, error: claimError } = await adminClient.rpc(
      "claim_document_analysis",
      {
        p_document_id: documentId,
        p_user_id: user.id,
      },
    );

    if (claimError) {
      throw new AppError(
        409,
        "DOCUMENT_CLAIM_FAILED",
        "Ce document ne peut pas être analysé dans son état actuel.",
        claimError,
      );
    }

    if (claimState === "completed") {
      const { data: existingAnalysis, error: existingError } =
        await adminClient
          .from("document_analyses")
          .select(
            "id,document_id,summary,overall_confidence,result_json,created_at,updated_at",
          )
          .eq("document_id", documentId)
          .eq("user_id", user.id)
          .maybeSingle();

      if (existingError || !existingAnalysis) {
        throw new AppError(
          500,
          "ANALYSIS_RESULT_NOT_FOUND",
          "L'analyse est indiquée comme terminée mais son résultat est introuvable.",
          existingError,
        );
      }

      return jsonResponse({
        success: true,
        already_completed: true,
        analysis: existingAnalysis,
      });
    }

    if (claimState === "processing") {
      throw new AppError(
        409,
        "ANALYSIS_ALREADY_PROCESSING",
        "Une analyse de ce document est déjà en cours.",
      );
    }

    if (claimState !== "claimed") {
      throw new AppError(
        409,
        "DOCUMENT_CLAIM_FAILED",
        "Le document n'a pas pu être réservé pour l'analyse.",
        claimState,
      );
    }

    claimedDocumentId = documentId;

    const { data: filesData, error: filesError } = await adminClient
      .from("document_files")
      .select(
        "id,document_id,object_path,original_name,mime_type,size_bytes,page_order",
      )
      .eq("document_id", documentId)
      .eq("user_id", user.id)
      .order("page_order", { ascending: true });

    if (filesError) {
      throw new AppError(
        500,
        "DOCUMENT_FILES_READ_FAILED",
        "Les fichiers du document n'ont pas pu être chargés.",
        filesError,
      );
    }

    const files = (filesData ?? []) as DocumentFileRow[];

    if (files.length === 0) {
      throw new AppError(
        422,
        "DOCUMENT_FILE_MISSING",
        "Aucun fichier n'est associé à ce document.",
      );
    }

    if (files.length > 5) {
      throw new AppError(
        422,
        "DOCUMENT_TOO_MANY_FILES",
        "Un document ne peut pas contenir plus de cinq fichiers.",
      );
    }

    let vehicle: VehicleRow | null = null;

    if (document.vehicle_id) {
      const { data: vehicleData, error: vehicleError } = await adminClient
        .from("vehicles")
        .select(
          "id,nickname,make,model,vehicle_year,fuel_type,mileage,registration_number",
        )
        .eq("id", document.vehicle_id)
        .eq("user_id", user.id)
        .maybeSingle();

      if (vehicleError) {
        throw new AppError(
          500,
          "VEHICLE_READ_FAILED",
          "Le véhicule associé n'a pas pu être chargé.",
          vehicleError,
        );
      }

      vehicle = vehicleData as VehicleRow | null;
    }

    const inputContent: JsonRecord[] = [
      {
        type: "input_text",
        text: buildUserContext(document, vehicle),
      },
    ];

    for (const file of files) {
      if (
        !["application/pdf", "image/jpeg", "image/png"].includes(
          file.mime_type,
        )
      ) {
        throw new AppError(
          422,
          "DOCUMENT_FILE_TYPE_INVALID",
          `Le fichier ${file.original_name} possède un format non autorisé.`,
        );
      }

      if (
        file.size_bytes <= 0 ||
        file.size_bytes > MAX_FILE_SIZE_BYTES
      ) {
        throw new AppError(
          422,
          "DOCUMENT_FILE_SIZE_INVALID",
          `Le fichier ${file.original_name} possède une taille invalide.`,
        );
      }

      const { data: blob, error: downloadError } =
        await adminClient.storage
          .from(BUCKET_ID)
          .download(file.object_path);

      if (downloadError || !blob) {
        throw new AppError(
          500,
          "DOCUMENT_FILE_DOWNLOAD_FAILED",
          `Le fichier ${file.original_name} n'a pas pu être téléchargé.`,
          downloadError,
        );
      }

      if (
        blob.size <= 0 ||
        blob.size > MAX_FILE_SIZE_BYTES
      ) {
        throw new AppError(
          422,
          "DOCUMENT_FILE_SIZE_INVALID",
          `Le fichier ${file.original_name} possède une taille invalide.`,
        );
      }

      const bytes = new Uint8Array(await blob.arrayBuffer());
      const base64 = bytesToBase64(bytes);

      if (file.mime_type === "application/pdf") {
        inputContent.push({
          type: "input_file",
          filename: normalizeFileName(file.original_name),
          file_data: `data:application/pdf;base64,${base64}`,
          detail: "high",
        });
      } else {
        inputContent.push({
          type: "input_image",
          image_url: `data:${file.mime_type};base64,${base64}`,
          detail: "high",
        });
      }
    }

    const openAiRequest = {
      model: openAiModel,
      store: false,
      reasoning: {
        effort: "low",
      },
      instructions: SYSTEM_PROMPT,
      input: [
        {
          role: "user",
          content: inputContent,
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "autoclair_document_analysis",
          description:
            "Analyse structurée d'un document automobile pour un particulier.",
          strict: true,
          schema: ANALYSIS_SCHEMA,
        },
      },
      max_output_tokens: 6000,
    };

    let openAiHttpResponse: Response;

    try {
      openAiHttpResponse = await fetch(
        "https://api.openai.com/v1/responses",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${openAiApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(openAiRequest),
          signal: AbortSignal.timeout(120_000),
        },
      );
    } catch (error) {
      const isTimeout =
        error instanceof DOMException &&
        error.name === "TimeoutError";

      throw new AppError(
        isTimeout ? 504 : 503,
        isTimeout ? "OPENAI_TIMEOUT" : "OPENAI_NETWORK_ERROR",
        isTimeout
          ? "L'analyse a dépassé le délai autorisé. Réessayez."
          : "Le service d'analyse est temporairement inaccessible.",
        error,
      );
    }

    let openAiResponse: JsonRecord;

    try {
      openAiResponse =
        (await openAiHttpResponse.json()) as JsonRecord;
    } catch (error) {
      throw new AppError(
        502,
        "OPENAI_RESPONSE_INVALID",
        "Le service d'analyse a renvoyé une réponse invalide.",
        error,
      );
    }

    if (!openAiHttpResponse.ok) {
      throw mapOpenAiError(
        openAiHttpResponse.status,
        openAiResponse,
      );
    }

    if (openAiResponse.status === "incomplete") {
      throw new AppError(
        502,
        "OPENAI_RESPONSE_INCOMPLETE",
        "L'analyse n'a pas pu être terminée entièrement.",
        openAiResponse.incomplete_details,
      );
    }

    const outputText = getOutputText(openAiResponse);

    if (!outputText) {
      throw new AppError(
        502,
        "OPENAI_OUTPUT_EMPTY",
        "Le service d'analyse n'a produit aucun résultat.",
      );
    }

    let parsedResult: unknown;

    try {
      parsedResult = JSON.parse(outputText);
    } catch (error) {
      throw new AppError(
        502,
        "OPENAI_OUTPUT_NOT_JSON",
        "Le résultat de l'analyse n'est pas un JSON valide.",
        error,
      );
    }

    const result = validateAnalysisResult(parsedResult);

    const usage =
      typeof openAiResponse.usage === "object" &&
      openAiResponse.usage !== null
        ? (openAiResponse.usage as JsonRecord)
        : {};

    const inputTokens =
      typeof usage.input_tokens === "number"
        ? Math.trunc(usage.input_tokens)
        : null;

    const outputTokens =
      typeof usage.output_tokens === "number"
        ? Math.trunc(usage.output_tokens)
        : null;

    const responseId =
      typeof openAiResponse.id === "string"
        ? openAiResponse.id
        : null;

    const { data: analysisId, error: completeError } =
      await adminClient.rpc("complete_document_analysis", {
        p_document_id: documentId,
        p_user_id: user.id,
        p_model: openAiModel,
        p_prompt_version: PROMPT_VERSION,
        p_schema_version: SCHEMA_VERSION,
        p_openai_response_id: responseId,
        p_summary: (result.summary as string).trim(),
        p_overall_confidence: result.overall_confidence,
        p_result_json: result,
        p_input_tokens: inputTokens,
        p_output_tokens: outputTokens,
      });

    if (completeError || !analysisId) {
      throw new AppError(
        500,
        "ANALYSIS_SAVE_FAILED",
        "Le résultat de l'analyse n'a pas pu être enregistré.",
        completeError,
      );
    }

    claimedDocumentId = null;

    return jsonResponse({
      success: true,
      already_completed: false,
      analysis: {
        id: analysisId,
        document_id: documentId,
        summary: result.summary,
        overall_confidence: result.overall_confidence,
        result_json: result,
      },
    });
  } catch (error) {
    const appError =
      error instanceof AppError
        ? error
        : new AppError(
            500,
            "UNEXPECTED_ERROR",
            "Une erreur inattendue est survenue pendant l'analyse.",
            error,
          );

    console.error(
      JSON.stringify({
        error_code: appError.code,
        message: appError.message,
        internal_details: appError.internalDetails,
      }),
    );

    if (
      claimedDocumentId &&
      authenticatedUserId &&
      adminClient
    ) {
      await markAnalysisFailed(
        adminClient,
        claimedDocumentId,
        authenticatedUserId,
        appError.code,
      );
    }

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
