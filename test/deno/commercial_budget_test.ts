import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.16";
import { requireCommercialBudget } from "../../supabase/functions/_shared/commercial_budget.ts";

Deno.test("commercial budget refuses missing admin (fail closed)", async () => {
  await assertRejects(
    () => requireCommercialBudget(null, "user-id", "legal"),
    Error, "COMMERCIAL_BUDGET_UNAVAILABLE",
  );
});

Deno.test("commercial budget refuses unavailable SQL policy", async () => {
  await assertRejects(
    () => requireCommercialBudget({
      rpc: async () => ({ data: null, error: { message: "function missing" } }),
    }, "user-id", "valuation"),
    Error, "COMMERCIAL_BUDGET_UNAVAILABLE",
  );
});

Deno.test("commercial budget refuses global user/feature cap", async () => {
  await assertRejects(
    () => requireCommercialBudget({
      rpc: async () => ({
        data: {allowed:false,reason:"COMMERCIAL_DAILY_LIMIT"},
        error:null,
      }),
    }, "user-id", "tire_ai"),
    Error, "COMMERCIAL_DAILY_LIMIT",
  );
});

Deno.test("commercial budget refuses unconfigured feature", async () => {
  await assertRejects(
    () => requireCommercialBudget({
      rpc: async () => ({
        data: {allowed:false,reason:"FEATURE_NOT_CONFIGURED"},
        error:null,
      }),
    }, "user-id", "unrecognized"),
    Error, "COMMERCIAL_FEATURE_UNAVAILABLE",
  );
});

Deno.test("commercial budget sends server generated idempotency key", async () => {
  let calls=0;
  const keys=new Set<string>();
  const admin={
    rpc: async (name:string, args:Record<string,unknown>) => {
      calls+=1;
      assertEquals(name,"commercial_try_feature");
      assertEquals(args.p_user_id,"uuid-of-authenticated-user");
      assertEquals(args.p_feature,"parking");
      assert(typeof args.p_operation_key==="string");
      assert(/^[a-f0-9-]{36}$/i.test(args.p_operation_key as string));
      keys.add(args.p_operation_key as string);
      return { data: {allowed:true,mode:"metered"},error:null };
    },
  };
  await requireCommercialBudget(admin,"uuid-of-authenticated-user","parking");
  await requireCommercialBudget(admin,"uuid-of-authenticated-user","parking");
  assertEquals(calls,2);
  assertEquals(keys.size,2);
});
