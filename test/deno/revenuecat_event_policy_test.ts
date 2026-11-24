import { assertEquals } from "jsr:@std/assert@1.0.16";
import { commercialWebhookAction } from "../../supabase/functions/_shared/revenuecat_event_policy.ts";

Deno.test("RevenueCat non-renewing purchase allocates verified consumable", () => {
  assertEquals(commercialWebhookAction("NON_RENEWING_PURCHASE",true), "grant");
});
Deno.test("RevenueCat CANCELLATION refunds consumable instead of orphaning units", () => {
  assertEquals(commercialWebhookAction("CANCELLATION",true), "refund");
  assertEquals(commercialWebhookAction("REFUND",true), "refund");
});
Deno.test("Subscription cancellation is NOT immediate revocation", () => {
  assertEquals(commercialWebhookAction("CANCELLATION",false), "sync_subscription");
  assertEquals(commercialWebhookAction("EXPIRATION",false), "sync_subscription");
  assertEquals(commercialWebhookAction("RENEWAL",false), "sync_subscription");
});
Deno.test("No credits on unrelated consumable events", () => {
  for(const type of ["TEST","INITIAL_PURCHASE","RENEWAL","EXPIRATION","UNCANCELLATION"]) {
    assertEquals(commercialWebhookAction(type,true), "sync_subscription");
  }
});
