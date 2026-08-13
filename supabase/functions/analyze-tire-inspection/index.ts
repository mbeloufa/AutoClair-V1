import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const OPENAI_MODEL = "gpt-5.6-terra";
const BUCKET = "tire-inspections";
const REQUIRED_SLOTS = [
  "FRONT_LEFT_TREAD",
  "FRONT_RIGHT_TREAD",
  "REAR_LEFT_TREAD",
  "REAR_RIGHT_TREAD",
  "FRONT_SIDEWALL",
  "REAR_SIDEWALL",
] as const;
const MERCHANT_DOMAINS = ["allopneus.com", "123pneus.fr"];

const analysisSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    status: { type: "string", enum: ["READY", "NEEDS_RETAKE"] },
    global_status: {
      type: "string",
      enum: ["OK", "WATCH", "REPLACE_SOON", "REPLACE_NOW", "URGENT_PROFESSIONAL_CHECK", "UNKNOWN"],
    },
    summary: { type: "string" },
    professional_message: { type: "string" },
    replacement_recommended: { type: "boolean" },
    front_dimension: { type: ["string", "null"] },
    rear_dimension: { type: ["string", "null"] },
    wheels: {
      type: "array",
      minItems: 4,
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          position: { type: "string", enum: ["FRONT_LEFT", "FRONT_RIGHT", "REAR_LEFT", "REAR_RIGHT"] },
          condition: {
            type: "string",
            enum: ["OK", "WATCH", "REPLACE_SOON", "REPLACE_NOW", "URGENT_PROFESSIONAL_CHECK", "UNKNOWN"],
          },
          confidence: { type: "string", enum: ["HIGH", "MEDIUM", "LOW"] },
          tread_assessment: { type: "string" },
          visible_findings: { type: "array", maxItems: 8, items: { type: "string" } },
          retake_required: { type: "boolean" },
          retake_reason: { type: ["string", "null"] },
        },
        required: [
          "position", "condition", "confidence", "tread_assessment", "visible_findings",
          "retake_required", "retake_reason",
        ],
      },
    },
    sidewalls: {
      type: "array",
      minItems: 2,
      maxItems: 2,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          axle: { type: "string", enum: ["FRONT", "REAR"] },
          dimension: { type: ["string", "null"] },
          load_speed_index: { type: ["string", "null"] },
          brand: { type: ["string", "null"] },
          model: { type: ["string", "null"] },
          tire_type: { type: "string", enum: ["SUMMER", "WINTER", "ALL_SEASON", "UNKNOWN"] },
          markings: { type: "array", maxItems: 12, items: { type: "string" } },
          dot_code: { type: ["string", "null"] },
          confidence: { type: "string", enum: ["HIGH", "MEDIUM", "LOW"] },
          retake_required: { type: "boolean" },
          retake_reason: { type: ["string", "null"] },
        },
        required: [
          "axle", "dimension", "load_speed_index", "brand", "model", "tire_type", "markings",
          "dot_code", "confidence", "retake_required", "retake_reason",
        ],
      },
    },
    photo_quality: {
      type: "array",
      minItems: 6,
      maxItems: 6,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          slot: { type: "string", enum: REQUIRED_SLOTS },
          status: { type: "string", enum: ["GOOD", "ACCEPTABLE", "RETAKE"] },
          reason: { type: "string" },
        },
        required: ["slot", "status", "reason"],
      },
    },
  },
  required: [
    "status", "global_status", "summary", "professional_message", "replacement_recommended",
    "front_dimension", "rear_dimension", "wheels", "sidewalls", "photo_quality",
  ],
};

const singlePhotoQualitySchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    status: { type: "string", enum: ["GOOD", "ACCEPTABLE", "RETAKE"] },
    message: { type: "string" },
    tip: { type: ["string", "null"] },
  },
  required: ["status", "message", "tip"],
};

const offersSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    offers: {
      type: "array",
      maxItems: 8,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          merchant: { type: "string", enum: ["Allopneus", "123pneus"] },
          product_name: { type: "string" },
          dimension: { type: "string" },
          tire_type: { type: "string", enum: ["SUMMER", "WINTER", "ALL_SEASON", "UNKNOWN"] },
          unit_price_eur: { type: "number" },
          url: { type: "string" },
        },
        required: ["merchant", "product_name", "dimension", "tire_type", "unit_price_eur", "url"],
      },
    },
  },
  required: ["offers"],
};

type SourceRef = { url: string; title: string };

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function outputText(response: any): string | null {
  if (typeof response?.output_text === "string" && response.output_text.trim()) {
    return response.output_text.trim();
  }
  for (const item of response?.output ?? []) {
    if (item?.type !== "message") continue;
    for (const content of item?.content ?? []) {
      if (content?.type === "output_text" && typeof content?.text === "string") {
        return content.text.trim();
      }
    }
  }
  return null;
}

function hostAllowed(url: string, domains: string[]): boolean {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return domains.some((domain) => host === domain || host.endsWith(`.${domain}`));
  } catch (_) {
    return false;
  }
}

function collectSources(response: any): SourceRef[] {
  const values: SourceRef[] = [];
  const add = (url: unknown, title: unknown) => {
    if (typeof url !== "string" || !hostAllowed(url, MERCHANT_DOMAINS)) return;
    values.push({ url, title: typeof title === "string" ? title : "" });
  };
  for (const item of response?.output ?? []) {
    if (item?.type === "web_search_call") {
      for (const source of item?.action?.sources ?? []) add(source?.url, source?.title);
    }
    if (item?.type === "message") {
      for (const content of item?.content ?? []) {
        for (const annotation of content?.annotations ?? []) {
          if (annotation?.type === "url_citation") add(annotation?.url, annotation?.title);
        }
      }
    }
  }
  const unique = new Map<string, SourceRef>();
  for (const item of values) unique.set(item.url, item);
  return Array.from(unique.values());
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const size = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += size) {
    binary += String.fromCharCode(...bytes.subarray(offset, Math.min(offset + size, bytes.length)));
  }
  return btoa(binary);
}

function normalizedDimension(value: unknown): string | null {
  const text = String(value ?? "").toUpperCase().replace(/\s+/g, " ").trim();
  const match = text.match(/\b(\d{3})\s*\/\s*(\d{2,3})\s*R\s*(\d{2})\b/);
  if (!match) return null;
  return `${match[1]}/${match[2]} R${match[3]}`;
}

async function analyzeImages(openaiKey: string, images: Array<{ slot: string; dataUrl: string }>) {
  const content: any[] = [{
    type: "input_text",
    text: [
      "You are the visual tire safety pre-assessment system for AutoClair in France.",
      "Analyze ONLY what is visibly supported by the six supplied photographs.",
      "This is a safety-related pre-assessment, never a certified inspection and never a substitute for a tire professional.",
      "Never estimate tread depth in millimetres from an ordinary photograph.",
      "You may describe proximity to visible tread-wear indicators (TWI) only when those indicators are clearly visible.",
      "Never infer SUMMER/WINTER/ALL_SEASON from tread pattern alone. Use explicit readable sidewall markings or a clearly readable model designation; otherwise return UNKNOWN.",
      "Do not invent brand, model, size, indices, DOT, M+S, 3PMSF, RunFlat or any characteristic that is not readable.",
      "Flag RETAKE whenever blur, darkness, framing, dirt, glare or angle prevents a responsible assessment.",
      "Potential bulge, exposed cord, deep cut, structural deformation or severe visible tread condition must trigger URGENT_PROFESSIONAL_CHECK or REPLACE_NOW as appropriate and cautious wording.",
      "Uneven wear may suggest checking pressure/alignment/suspension, but never diagnose the mechanical cause from the photo.",
      "Return exactly four wheel assessments and two sidewall assessments matching the slots.",
      "The professional_message must explicitly state in French that the AI analysis is informative and does not replace a professional tire inspection.",
      "Write all user-facing fields in very simple everyday French for people with no automotive knowledge.",
      "Avoid automotive jargon in user-facing text. Do not use words such as flanc, bande de roulement, epaulement or train avant/arriere; say cote du pneu, partie qui touche la route, bord du pneu, roues avant/arriere instead.",
      "Keep each visible finding short (ideally under 12 words) and the summary to at most two short sentences.",
      "Explain only what the person needs to know or do next; keep technical classifications internal.",
    ].join("\n"),
  }];
  for (const image of images) {
    content.push({ type: "input_text", text: `PHOTO SLOT: ${image.slot}` });
    content.push({ type: "input_image", image_url: image.dataUrl, detail: "original" });
  }
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openaiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      store: false,
      reasoning: { effort: "low" },
      input: [{ role: "user", content }],
      text: {
        format: {
          type: "json_schema",
          name: "autoclair_tire_visual_inspection",
          strict: true,
          schema: analysisSchema,
        },
      },
      max_output_tokens: 6500,
    }),
  });
  const raw = await response.text();
  if (!response.ok) throw new Error(`OPENAI_${response.status}:${raw.slice(0, 600)}`);
  const decoded = JSON.parse(raw);
  const text = outputText(decoded);
  if (!text) throw new Error("OPENAI_EMPTY_OUTPUT");
  const analysis = JSON.parse(text);
  const qualities = Array.isArray(analysis?.photo_quality) ? analysis.photo_quality : [];
  if (qualities.some((item: any) => item?.status === "RETAKE")) analysis.status = "NEEDS_RETAKE";
  analysis.front_dimension = normalizedDimension(analysis.front_dimension);
  analysis.rear_dimension = normalizedDimension(analysis.rear_dimension);
  return analysis;
}

async function validateSinglePhoto(
  openaiKey: string,
  slot: string,
  dataUrl: string,
): Promise<any> {
  const tread = slot.endsWith("_TREAD");
  const expected = tread
    ? "the tire area that contacts the road must be large, sharp and useful for a visual wear check"
    : "the side of the tire and its markings must be large enough to read";
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openaiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      store: false,
      reasoning: { effort: "low" },
      input: [{
        role: "user",
        content: [
          {
            type: "input_text",
            text: [
              `Validate capture quality only for slot ${slot}.`,
              `Expected: ${expected}.`,
              "Do NOT diagnose wear, safety, brand or tire condition in this step.",
              "Return RETAKE when the intended tire/area is missing, too small, blurred, too dark/bright, strongly obstructed, or the angle does not allow the expected visual check.",
              "GOOD means clearly usable. ACCEPTABLE means usable despite a minor imperfection. RETAKE means a new photo is required before continuing.",
              "Write message and tip in very simple French for a driver with no automotive knowledge. Maximum 12 words per field.",
            ].join("\\n"),
          },
          { type: "input_image", image_url: dataUrl, detail: "low" },
        ],
      }],
      text: {
        format: {
          type: "json_schema",
          name: "autoclair_tire_single_photo_quality",
          strict: true,
          schema: singlePhotoQualitySchema,
        },
      },
      max_output_tokens: 220,
    }),
  });
  const raw = await response.text();
  if (!response.ok) {
    throw new Error(`OPENAI_PHOTO_QUALITY_${response.status}:${raw.slice(0, 500)}`);
  }
  const decoded = JSON.parse(raw);
  const text = outputText(decoded);
  if (!text) throw new Error("OPENAI_PHOTO_QUALITY_EMPTY");
  const quality = JSON.parse(text);
  if (!["GOOD", "ACCEPTABLE", "RETAKE"].includes(String(quality?.status))) {
    throw new Error("OPENAI_PHOTO_QUALITY_INVALID");
  }
  return quality;
}

async function researchOffers(
  openaiKey: string,
  dimensions: string[],
  tireTypes: string[],
): Promise<any[]> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openaiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      store: false,
      reasoning: { effort: "low" },
      tools: [{ type: "web_search", filters: { allowed_domains: MERCHANT_DOMAINS } }],
      tool_choice: "required",
      include: ["web_search_call.action.sources"],
      input: [
        "Find currently displayed retail tire prices in France on Allopneus and 123pneus for the requested dimensions.",
        `Dimensions: ${dimensions.join(", ")}.`,
        `Preferred tire types when known: ${tireTypes.join(", ") || "UNKNOWN"}.`,
        "Return only an offer when the current page explicitly displays the exact dimension, product name and a unit price in euros.",
        "Use the exact product/source URL returned by web search. Do not invent URLs, prices, availability or discounts.",
        "If the evidence is insufficient, omit the offer. A partial or empty list is correct.",
      ].join("\n"),
      text: {
        format: {
          type: "json_schema",
          name: "autoclair_tire_retail_offers",
          strict: true,
          schema: offersSchema,
        },
      },
      max_output_tokens: 3500,
    }),
  });
  const raw = await response.text();
  if (!response.ok) throw new Error(`OPENAI_OFFERS_${response.status}:${raw.slice(0, 600)}`);
  const decoded = JSON.parse(raw);
  const text = outputText(decoded);
  if (!text) return [];
  const payload = JSON.parse(text);
  const sourceUrls = new Set(collectSources(decoded).map((item) => item.url));
  return (Array.isArray(payload?.offers) ? payload.offers : []).filter((offer: any) => {
    const url = String(offer?.url ?? "");
    const price = Number(offer?.unit_price_eur);
    return sourceUrls.has(url) && hostAllowed(url, MERCHANT_DOMAINS) && Number.isFinite(price) && price > 0;
  }).slice(0, 8);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { success: false, error: "METHOD_NOT_ALLOWED" });
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRole || !openaiKey) {
      return json(503, { success: false, error: "BACKEND_NOT_CONFIGURED" });
    }

    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) return json(401, { success: false, error: "AUTH_REQUIRED" });
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const admin = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false } });
    const token = authorization.slice("Bearer ".length);
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    const user = authData?.user;
    if (authError || !user) return json(401, { success: false, error: "AUTH_REQUIRED" });

    const body = await req.json().catch(() => ({}));
    const inspectionId = String(body?.inspection_id ?? "").trim();
    const action = String(body?.action ?? "analyze").trim().toLowerCase();
    if (!inspectionId) return json(400, { success: false, error: "INSPECTION_REQUIRED" });

    const { data: inspection, error: inspectionError } = await admin
      .from("tire_ai_inspections")
      .select("id,user_id,vehicle_id,status,analysis_json,replacement_recommended,front_dimension,rear_dimension")
      .eq("id", inspectionId)
      .maybeSingle();
    if (inspectionError || !inspection || inspection.user_id !== user.id) {
      return json(404, { success: false, error: "INSPECTION_NOT_FOUND" });
    }

    if (action === "validate_photo") {
      const slot = String(body?.slot ?? "").trim().toUpperCase();
      if (!REQUIRED_SLOTS.includes(slot as any)) {
        return json(400, { success: false, error: "PHOTO_SLOT_INVALID" });
      }
      const { data: photo, error: photoError } = await admin
        .from("tire_ai_photos")
        .select("slot,storage_path,content_type")
        .eq("inspection_id", inspectionId)
        .eq("slot", slot)
        .maybeSingle();
      if (photoError) throw photoError;
      if (!photo) return json(404, { success: false, error: "PHOTO_NOT_FOUND" });

      const { data, error: downloadError } = await admin.storage
        .from(BUCKET)
        .download(photo.storage_path);
      if (downloadError || !data) throw new Error(`PHOTO_DOWNLOAD_FAILED:${slot}`);
      const bytes = new Uint8Array(await data.arrayBuffer());
      const contentType = String(photo.content_type ?? "image/jpeg");
      const dataUrl = `data:${contentType};base64,${toBase64(bytes)}`;
      const quality = await validateSinglePhoto(openaiKey, slot, dataUrl);
      return json(200, { success: true, quality });
    }

    if (action === "offers") {
      if (inspection.status !== "READY") return json(409, { success: false, error: "ANALYSIS_NOT_READY" });
      if (inspection.replacement_recommended !== true) {
        return json(409, { success: false, error: "REPLACEMENT_NOT_RECOMMENDED" });
      }
      const dimensions = [normalizedDimension(inspection.front_dimension), normalizedDimension(inspection.rear_dimension)]
        .filter((value, index, all): value is string => !!value && all.indexOf(value) === index);
      if (!dimensions.length) return json(409, { success: false, error: "DIMENSION_UNCERTAIN" });
      const sidewalls = Array.isArray(inspection.analysis_json?.sidewalls) ? inspection.analysis_json.sidewalls : [];
      const tireTypes = sidewalls
        .map((item: any) => String(item?.tire_type ?? "UNKNOWN"))
        .filter((value: string, index: number, all: string[]) => value !== "UNKNOWN" && all.indexOf(value) === index);
      const offers = await researchOffers(openaiKey, dimensions, tireTypes);
      await admin.from("tire_ai_inspections").update({
        offers_json: offers,
        offers_researched_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", inspectionId);
      return json(200, { success: true, offers });
    }

    if (action !== "analyze") return json(400, { success: false, error: "UNKNOWN_ACTION" });
    const { data: photos, error: photosError } = await admin
      .from("tire_ai_photos")
      .select("slot,storage_path,content_type")
      .eq("inspection_id", inspectionId);
    if (photosError) throw photosError;
    const bySlot = new Map((photos ?? []).map((row: any) => [String(row.slot), row]));
    if (REQUIRED_SLOTS.some((slot) => !bySlot.has(slot))) {
      return json(409, { success: false, error: "PHOTOS_INCOMPLETE" });
    }

    await admin.from("tire_ai_inspections").update({
      status: "ANALYZING",
      error_code: null,
      updated_at: new Date().toISOString(),
    }).eq("id", inspectionId);

    const images: Array<{ slot: string; dataUrl: string }> = [];
    for (const slot of REQUIRED_SLOTS) {
      const row: any = bySlot.get(slot);
      const { data, error } = await admin.storage.from(BUCKET).download(row.storage_path);
      if (error || !data) throw new Error(`PHOTO_DOWNLOAD_FAILED:${slot}`);
      const bytes = new Uint8Array(await data.arrayBuffer());
      const contentType = String(row.content_type ?? "image/jpeg");
      images.push({ slot, dataUrl: `data:${contentType};base64,${toBase64(bytes)}` });
    }

    const analysis = await analyzeImages(openaiKey, images);
    const needsRetake = analysis.status === "NEEDS_RETAKE";
    const status = needsRetake ? "NEEDS_RETAKE" : "READY";
    const replacementRecommended = analysis.replacement_recommended === true;
    const { error: updateError } = await admin.from("tire_ai_inspections").update({
      status,
      global_status: analysis.global_status ?? "UNKNOWN",
      summary: String(analysis.summary ?? ""),
      analysis_json: analysis,
      front_dimension: normalizedDimension(analysis.front_dimension),
      rear_dimension: normalizedDimension(analysis.rear_dimension),
      replacement_recommended: replacementRecommended,
      model_id: OPENAI_MODEL,
      analyzed_at: new Date().toISOString(),
      error_code: null,
      updated_at: new Date().toISOString(),
    }).eq("id", inspectionId);
    if (updateError) throw updateError;

    if (!needsRetake) {
      const paths = (photos ?? []).map((row: any) => String(row.storage_path)).filter(Boolean);
      if (paths.length) await admin.storage.from(BUCKET).remove(paths);
      await admin.from("tire_ai_photos").delete().eq("inspection_id", inspectionId);
    }

    return json(200, { success: true, analysis });
  } catch (error) {
    console.error("analyze-tire-inspection", error);
    return json(500, { success: false, error: "TIRE_ANALYSIS_FAILED" });
  }
});