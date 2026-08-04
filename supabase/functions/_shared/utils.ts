export type JsonMap = Record<string, unknown>;

export function isRecord(value: unknown): value is JsonMap {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function asString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

export function asNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const normalized = value.replace(",", ".");
    const parsed = Number(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

export function asInteger(value: unknown): number | null {
  const parsed = asNumber(value);
  if (parsed === null) return null;
  return Math.round(parsed);
}

export function asBoolean(value: unknown): boolean {
  return value === true;
}

export function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function isoDate(value: unknown): string | null {
  const text = asString(value);
  if (!text) return null;
  const match = text.match(/^\d{4}-\d{2}-\d{2}/);
  return match ? match[0] : null;
}

export function safeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return "UNKNOWN_ERROR";
}

export async function readJsonBody(req: Request): Promise<JsonMap> {
  try {
    const body = await req.json();
    if (!isRecord(body)) throw new Error("INVALID_JSON_BODY");
    return body;
  } catch {
    throw new Error("INVALID_JSON_BODY");
  }
}

export async function sha256Hex(value: unknown): Promise<string> {
  const encoded = new TextEncoder().encode(JSON.stringify(value));
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function daysBetween(dateText: string, now = new Date()): number {
  const date = new Date(`${dateText}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return Number.POSITIVE_INFINITY;
  return Math.floor((now.getTime() - date.getTime()) / 86_400_000);
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
