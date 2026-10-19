import { createClient } from "npm:@supabase/supabase-js@2";

const json = (status: number, body: unknown) => new Response(
  JSON.stringify(body), { status, headers: { "Content-Type":"application/json","Cache-Control":"no-store" } },
);
type RecordAny = Record<string, unknown>;
const asObject = (value: unknown): RecordAny =>
  value && typeof value === "object" && !Array.isArray(value) ? value as RecordAny : {};
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function expectedStore(value: unknown): string | null {
  const key = String(value ?? "").toUpperCase();
  if (key === "PLAY_STORE") return "play_store";
  if (key === "APP_STORE") return "app_store";
  if (key === "AMAZON") return "amazon";
  if (key === "STRIPE") return "stripe";
  if (key === "TEST_STORE") return "test";
  return null;
}

async function subscriberFor(userId: string, secret: string): Promise<RecordAny> {
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    { headers: { Authorization: `Bearer ${secret}`, Accept: "application/json" } },
  );
  if (!response.ok) throw new Error("REVENUECAT_UNAVAILABLE");
  return asObject(asObject(await response.json()).subscriber);
}

function transactionPresent(
  subscriber: RecordAny, productId: string, transactionId: string,
): boolean {
  const array = asObject(subscriber.non_subscriptions)[productId];
  return Array.isArray(array) && array.some((entry: unknown) => {
    const value = asObject(entry);
    return value.id === transactionId ||
      value.transaction_id === transactionId ||
      value.original_transaction_id === transactionId;
  });
}

async function syncPremium(admin: ReturnType<typeof createClient<any>>, userId: string, subscriber: RecordAny) {
  const entitlement = asObject(subscriber.entitlements).premium;
  const e = asObject(entitlement);
  const expiresAt = typeof e.expires_date === "string" ? e.expires_date : null;
  const graceAt = typeof e.grace_period_expires_date === "string"
    ? e.grace_period_expires_date : null;
  const validDates = [expiresAt,graceAt].filter((v): v is string => v !== null)
    .map((v) => new Date(v)).filter((v) => !Number.isNaN(v.valueOf()));
  const expiry = validDates.sort((a,b)=>b.valueOf()-a.valueOf())[0] ?? null;
  // No fake lifetime access when provider returns no expiration.
  const active = entitlement !== undefined && expiry !== null && expiry > new Date();
  const { error } = await admin.rpc("upsert_vehicle_360_entitlement", {
    p_user_id: userId,
    p_status: active ? "active" : entitlement ? "expired" : "inactive",
    p_source: "revenuecat",
    p_external_reference: "premium",
    p_starts_at: typeof e.purchase_date === "string" ? e.purchase_date : new Date().toISOString(),
    p_expires_at: expiry?.toISOString() ?? new Date().toISOString(),
    p_metadata: { provider:"revenuecat",product_identifier:e.product_identifier ?? null },
  });
  if (error) throw new Error("PREMIUM_SYNC_FAILED");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json(405,{ error:"METHOD_NOT_ALLOWED" });
  const expected = Deno.env.get("REVENUECAT_WEBHOOK_AUTHORIZATION");
  const apiKey = Deno.env.get("REVENUECAT_SECRET_API_KEY");
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!expected || !apiKey || !url || !serviceKey)
    return json(503,{ error:"WEBHOOK_NOT_CONFIGURED" });
  if (request.headers.get("authorization") !== expected)
    return json(401,{ error:"UNAUTHORIZED" });

  try {
    const body = asObject(await request.json());
    const event = asObject(body.event);
    const type = String(event.type ?? "");
    const userId = String(event.app_user_id ?? "");
    if (!uuidPattern.test(userId)) return json(400,{ error:"INVALID_USER_ID" });
    const environment = String(event.environment ?? "").toUpperCase();
    if (environment !== "PRODUCTION" && environment !== "SANDBOX")
      return json(400,{ error:"INVALID_ENVIRONMENT" });
    if (environment === "SANDBOX" &&
       Deno.env.get("COMMERCIAL_ALLOW_SANDBOX_PURCHASES") !== "true")
      return json(200,{ accepted:true, sandbox_ignored:true });
    const admin = createClient<any>(url,serviceKey,{auth:{persistSession:false}});
    const subscriber = await subscriberFor(userId,apiKey);
    if (type !== "NON_RENEWING_PURCHASE" && type !== "REFUND") {
      await syncPremium(admin,userId,subscriber);
      return json(200,{ accepted:true, subscription_synced:true });
    }

    const productId = String(event.product_id ?? "");
    const store = expectedStore(event.store);
    const transactionId = String(event.transaction_id ?? event.original_transaction_id ?? "");
    if (!store || !productId || !transactionId)
      return json(400,{ error:"PURCHASE_FIELDS_MISSING" });

    const { data:product, error:productError } = await admin
      .from("commercial_products")
      .select("code,kind,active")
      .eq("store_product_id",productId).maybeSingle();
    if (productError) throw new Error("PRODUCT_LOOKUP_FAILED");
    if (!product || product.kind !== "consumable") {
      // Subscription refund or an unknown product: synchronize subscription
      // rather than inventing or revoking a consumable.
      await syncPremium(admin,userId,subscriber);
      return json(200,{accepted:true,subscription_synced:true});
    }

    if (type === "REFUND") {
      const {error}=await admin.rpc("commercial_revoke_purchase",{
        p_user_id:userId,
        p_product_code:product.code,
        p_store:store,
        p_transaction_id:transactionId,
        p_environment:environment,
      });
      if (error) throw new Error("REFUND_RECONCILIATION_FAILED");
      return json(200,{ accepted:true, refunded:true });
    }

    if (!product.active) {
      return json(200,{accepted:true,product_unconfigured:true});
    }
    // Do not trust merely the event payload. Cross-check the receipt
    // against the provider's verified subscriber purchase history.
    if (!transactionPresent(subscriber,productId,transactionId)) {
      throw new Error("VERIFIED_PURCHASE_NOT_YET_VISIBLE");
    }
    const purchasedMs = Number(event.purchased_at_ms);
    const purchasedAt = Number.isFinite(purchasedMs) && purchasedMs > 0
      ? new Date(purchasedMs).toISOString() : new Date().toISOString();
    const {error}=await admin.rpc("commercial_grant_verified_purchase",{
      p_user_id:userId,
      p_store:store,
      p_transaction_id:transactionId,
      p_product_code:product.code,
      p_environment:environment,
      p_purchased_at:purchasedAt,
    });
    if (error) throw new Error("PURCHASE_GRANT_FAILED");
    return json(200,{ accepted:true, granted:true });
  } catch (error) {
    console.error("Commercial webhook failed",error instanceof Error ? error.message : "unknown");
    // RevenueCat retries non-2xx responses, preserving recoverability.
    return json(503,{ error:"RECONCILIATION_RETRY" });
  }
});
