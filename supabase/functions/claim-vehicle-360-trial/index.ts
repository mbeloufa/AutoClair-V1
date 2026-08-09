import { createClient } from "npm:@supabase/supabase-js@2";

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
  ) {
    super(message);
  }
}

function jsonResponse(payload: JsonRecord, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function bearerToken(req: Request): string {
  const authorization = req.headers.get("Authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match?.[1]) {
    throw new AppError(401, "AUTHENTICATION_REQUIRED", "Reconnectez-vous.");
  }
  return match[1];
}

async function accessState(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
): Promise<JsonRecord> {
  const reference = `trial:vehicle_360:${userId}`;

  const [{ data: events, error: eventsError }, { data: entitlement, error: entitlementError }] =
    await Promise.all([
      adminClient
        .from("vehicle_report_credit_events")
        .select("delta,external_reference")
        .eq("user_id", userId),
      adminClient
        .from("user_entitlements")
        .select("id")
        .eq("user_id", userId)
        .eq("entitlement_code", "vehicle_360")
        .eq("status", "active")
        .lte("starts_at", new Date().toISOString())
        .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
        .limit(1),
    ]);

  if (eventsError) {
    throw new AppError(500, "CREDIT_READ_FAILED", "L'accès Premium n'a pas pu être vérifié.");
  }
  if (entitlementError) {
    throw new AppError(500, "ENTITLEMENT_READ_FAILED", "L'accès Premium n'a pas pu être vérifié.");
  }

  const rows = Array.isArray(events) ? events : [];
  const creditBalance = rows.reduce((sum, row) => {
    const delta = typeof row.delta === "number" ? row.delta : Number(row.delta ?? 0);
    return sum + (Number.isFinite(delta) ? delta : 0);
  }, 0);

  const trialClaimed = rows.some(
    (row) => row.external_reference === reference,
  );

  return {
    success: true,
    entitled: Array.isArray(entitlement) && entitlement.length > 0,
    credit_balance: creditBalance,
    trial_claimed: trialClaimed,
    trial_available: !trialClaimed,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { success: false, error_code: "METHOD_NOT_ALLOWED" },
      405,
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      throw new AppError(500, "SERVER_CONFIGURATION_MISSING", "Configuration serveur incomplète.");
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const token = bearerToken(req);
    const {
      data: { user },
      error: userError,
    } = await adminClient.auth.getUser(token);

    if (userError || !user) {
      throw new AppError(401, "AUTHENTICATION_REQUIRED", "Reconnectez-vous.");
    }

    let body: JsonRecord = {};
    try {
      body = (await req.json()) as JsonRecord;
    } catch {
      body = {};
    }

    const action = body.action?.toString().trim().toLowerCase() || "status";
    if (action !== "status" && action !== "claim") {
      throw new AppError(400, "ACTION_INVALID", "Action invalide.");
    }

    if (action === "claim") {
      const reference = `trial:vehicle_360:${user.id}`;
      const { error: insertError } = await adminClient
        .from("vehicle_report_credit_events")
        .insert({
          user_id: user.id,
          delta: 1,
          event_type: "grant",
          source: "trial",
          external_reference: reference,
          metadata: { feature: "vehicle_360", quantity: 1 },
        });

      if (insertError && insertError.code !== "23505") {
        throw new AppError(500, "TRIAL_GRANT_FAILED", "L'essai gratuit n'a pas pu être activé.");
      }
    }

    return jsonResponse(await accessState(adminClient, user.id));
  } catch (error) {
    if (error instanceof AppError) {
      return jsonResponse(
        { success: false, error_code: error.code, message: error.message },
        error.status,
      );
    }

    return jsonResponse(
      {
        success: false,
        error_code: "TRIAL_SERVICE_UNAVAILABLE",
        message: "L'accès Premium est temporairement indisponible.",
      },
      500,
    );
  }
});
