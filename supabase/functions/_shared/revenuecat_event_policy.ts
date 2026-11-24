/**
 * RevenueCat subscription cancellation does not automatically mean a refund.
 * For non-renewing consumable products, CANCELLATION is the store refund signal.
 * The caller MUST verify product kind from our server-owned catalog first.
 * Reference: RevenueCat Webhooks > Event Types and Fields.
 */
export type CommercialWebhookAction = "grant" | "refund" | "sync_subscription";
export function commercialWebhookAction(eventType: string, consumable: boolean): CommercialWebhookAction {
  if (!consumable) return "sync_subscription";
  if (eventType === "NON_RENEWING_PURCHASE") return "grant";
  if (eventType === "CANCELLATION" || eventType === "REFUND") return "refund";
  return "sync_subscription";
}
