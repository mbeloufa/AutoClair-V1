import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2";

type JsonMap = Record<string, unknown>;

function parseKeyDictionary(name: string): Record<string, string> {
  const raw = Deno.env.get(name);
  if (!raw) return {};

  try {
    const parsed = JSON.parse(raw) as JsonMap;
    const result: Record<string, string> = {};

    for (const [key, value] of Object.entries(parsed)) {
      if (typeof value === "string" && value.trim()) {
        result[key] = value;
      }
    }

    return result;
  } catch {
    return {};
  }
}

function getPublishableKey(): string {
  const legacy = Deno.env.get("SUPABASE_ANON_KEY");
  if (legacy) return legacy;

  const keys = parseKeyDictionary("SUPABASE_PUBLISHABLE_KEYS");
  const first = keys.default ?? Object.values(keys)[0];
  if (!first) throw new Error("SUPABASE_PUBLISHABLE_KEY_MISSING");
  return first;
}

function getSecretKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;

  const keys = parseKeyDictionary("SUPABASE_SECRET_KEYS");
  const first = keys.default ?? Object.values(keys)[0];
  if (!first) throw new Error("SUPABASE_SECRET_KEY_MISSING");
  return first;
}

export type AuthContext = {
  user: User;
  token: string;
  userClient: SupabaseClient;
  adminClient: SupabaseClient;
};

export async function authenticate(req: Request): Promise<AuthContext> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) throw new Error("SUPABASE_URL_MISSING");

  const authorization = req.headers.get("Authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new Error("AUTHENTICATION_REQUIRED");

  const token = match[1].trim();
  if (!token) throw new Error("AUTHENTICATION_REQUIRED");

  const userClient = createClient(supabaseUrl, getPublishableKey(), {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  const { data, error } = await userClient.auth.getUser(token);
  if (error || !data.user) throw new Error("INVALID_OR_EXPIRED_TOKEN");

  const adminClient = createClient(supabaseUrl, getSecretKey(), {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  return {
    user: data.user,
    token,
    userClient,
    adminClient,
  };
}
