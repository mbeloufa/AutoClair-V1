/**
 * Called ONLY after authenticating the user, checking object ownership and
 * rejecting cached/no-cost requests. A fresh server UUID prevents clients
 * from reusing a request_key to bypass the cap. DB enforces per-user and
 * global daily limits atomically across all Edge Functions.
 *
 * This is abuse prevention, not a paid credit transaction. Emergency
 * deterministic safety guidance must remain accessible if AI is throttled.
 */
export async function requireCommercialBudget(
  admin: unknown,
  userId: string,
  feature: string,
): Promise<void> {
  if (!admin || typeof (admin as {rpc?:unknown}).rpc !== "function") {
    throw new Error("COMMERCIAL_BUDGET_UNAVAILABLE");
  }
  // Supabase 2.x can be loaded through npm: or esm.sh in legacy functions.
  // Cross-package types are structurally incompatible despite identical APIs.
  const client = admin as {
    rpc: (name:string,args:Record<string,unknown>)=>Promise<{
      data:Record<string,unknown>|null;
      error:{message:string}|null;
    }>;
  };
  const { data, error } = await client.rpc("commercial_try_feature", {
    p_user_id: userId,
    p_feature: feature,
    p_operation_key: crypto.randomUUID(),
  });
  if (error) {
    throw new Error("COMMERCIAL_BUDGET_UNAVAILABLE");
  }
  if (!data || data.allowed !== true) {
    throw new Error(
      data?.reason === "COMMERCIAL_DAILY_LIMIT"
        ? "COMMERCIAL_DAILY_LIMIT"
        : "COMMERCIAL_FEATURE_UNAVAILABLE",
    );
  }
}
