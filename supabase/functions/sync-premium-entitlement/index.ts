import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REVENUECAT_ENTITLEMENT = "premium";
const AUTOCLAIR_ENTITLEMENT_SOURCE = "revenuecat";
const AUTOCLAIR_EXTERNAL_REFERENCE = "premium";

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function dateValue(value: unknown): Date | null {
  if (typeof value !== "string" || value.trim() === "") return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function latestDate(a: Date | null, b: Date | null): Date | null {
  if (a == null) return b;
  if (b == null) return a;
  return a.getTime() >= b.getTime() ? a : b;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "UNAUTHORIZED" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "SERVER_CONFIGURATION_ERROR" }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return jsonResponse({ error: "UNAUTHORIZED" }, 401);
  }

  const revenueCatSecret = Deno.env.get("REVENUECAT_SECRET_API_KEY");
  if (!revenueCatSecret) {
    return jsonResponse(
      {
        configured: false,
        active: false,
        error: "BILLING_NOT_CONFIGURED",
      },
      503,
    );
  }

  const revenueCatResponse = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${
      encodeURIComponent(user.id)
    }`,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${revenueCatSecret}`,
        Accept: "application/json",
      },
    },
  );

  if (!revenueCatResponse.ok) {
    return jsonResponse(
      {
        configured: true,
        active: false,
        error: "REVENUECAT_UNAVAILABLE",
      },
      502,
    );
  }

  const revenueCatPayload = await revenueCatResponse.json();
  const subscriber = revenueCatPayload?.subscriber ?? {};
  const entitlement =
    subscriber?.entitlements?.[REVENUECAT_ENTITLEMENT] ?? null;

  const expires = dateValue(entitlement?.expires_date);
  const graceExpires = dateValue(
    entitlement?.grace_period_expires_date,
  );
  const effectiveExpiry = latestDate(expires, graceExpires);
  const now = new Date();

  const active = entitlement != null &&
    (effectiveExpiry == null ||
      effectiveExpiry.getTime() > now.getTime());

  const status = active
    ? "active"
    : entitlement != null
    ? "expired"
    : "inactive";

  const purchaseDate =
    dateValue(entitlement?.purchase_date)?.toISOString() ??
      now.toISOString();

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { error: upsertError } = await adminClient.rpc(
    "upsert_vehicle_360_entitlement",
    {
      p_user_id: user.id,
      p_status: status,
      p_source: AUTOCLAIR_ENTITLEMENT_SOURCE,
      p_external_reference: AUTOCLAIR_EXTERNAL_REFERENCE,
      p_starts_at: purchaseDate,
      p_expires_at: effectiveExpiry?.toISOString() ?? null,
      p_metadata: {
        provider: "revenuecat",
        entitlement: REVENUECAT_ENTITLEMENT,
        product_identifier:
          entitlement?.product_identifier ?? null,
        store_expiration_at: expires?.toISOString() ?? null,
        grace_period_expires_at:
          graceExpires?.toISOString() ?? null,
      },
    },
  );

  if (upsertError) {
    console.error(
      "Unable to sync AutoClair entitlement:",
      upsertError.message,
    );
    return jsonResponse(
      {
        configured: true,
        active: false,
        error: "AUTOCLAIR_ENTITLEMENT_SYNC_FAILED",
      },
      500,
    );
  }

  return jsonResponse({
    configured: true,
    active,
    expires_at: effectiveExpiry?.toISOString() ?? null,
  });
});
