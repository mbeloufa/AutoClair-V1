import { createClient } from "npm:@supabase/supabase-js@2.111.0";
import { decode } from "npm:@here/flexpolyline@0.1.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const HERE_ROUTE_URL = "https://router.hereapi.com/v8/routes";
const HERE_GEOCODE_URL = "https://geocode.search.hereapi.com/v1/geocode";
const MIN_SAVING_EUR = 2.50;
const MIN_SAVING_RATIO = 0.03;
const REQUEST_TIMEOUT_MS = 12000;

type Point = { lat: number; lng: number };
type ResolvedPlace = Point & { label: string };
type Candidate = {
  id: string; label: string; distance_km: number; duration_minutes: number;
  toll_eur: number; energy_quantity: number; energy_cost_eur: number;
  total_cost_eur: number; points: Point[];
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
const round = (v: number, d = 2) => Math.round(v * 10 ** d) / 10 ** d;
function numberOf(v: unknown): number | null {
  const n = Number(v); return Number.isFinite(n) ? n : null;
}
function pointOf(v: unknown): Point | null {
  if (!v || typeof v !== "object") return null;
  const o = v as Record<string, unknown>;
  const lat = numberOf(o.lat); const lng = numberOf(o.lng);
  if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return { lat, lng };
}
function clean(v: unknown, max = 160): string {
  return String(v ?? "").trim().replace(/\s+/g, " ").slice(0, max);
}
async function fetchJson(url: URL): Promise<any> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(url, { headers: { Accept: "application/json" }, signal: controller.signal });
    const raw = await response.text();
    if (!response.ok) throw new Error(`HERE_${response.status}:${raw.slice(0, 300)}`);
    return JSON.parse(raw);
  } finally {
    clearTimeout(timer);
  }
}
async function geocode(query: string, apiKey: string): Promise<ResolvedPlace> {
  const url = new URL(HERE_GEOCODE_URL);
  url.searchParams.set("q", query); url.searchParams.set("limit", "1");
  url.searchParams.set("lang", "fr-FR"); url.searchParams.set("apiKey", apiKey);
  const data = await fetchJson(url);
  const p = pointOf(data?.items?.[0]?.position);
  if (!p) throw new Error("PLACE_NOT_FOUND");
  return { ...p, label: clean(data?.items?.[0]?.title) || query };
}
async function resolvePlace(value: unknown, apiKey: string, fallback: string): Promise<ResolvedPlace> {
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const p = pointOf(obj);
    if (p) return { ...p, label: clean(obj.label) || fallback };
    const q = clean(obj.query); if (q) return geocode(q, apiKey);
  }
  const q = clean(value); if (q) return geocode(q, apiKey);
  throw new Error("PLACE_REQUIRED");
}
function addPoints(target: Point[], encoded: unknown) {
  if (typeof encoded !== "string") return;
  try {
    for (const row of decode(encoded).polyline ?? []) {
      if (!Array.isArray(row) || row.length < 2) continue;
      const lat = Number(row[0]); const lng = Number(row[1]);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      const last = target[target.length - 1];
      if (last && Math.abs(last.lat-lat) < 1e-7 && Math.abs(last.lng-lng) < 1e-7) continue;
      target.push({ lat, lng });
    }
  } catch (_) {}
}
function normalizedFuel(value: unknown): string {
  return String(value ?? "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}
function isFullElectric(value: unknown): boolean {
  const fuel = normalizedFuel(value);
  return fuel.includes("electri") && !fuel.includes("hybrid");
}
function hereFuelType(value: unknown): "diesel" | "petrol" {
  const fuel = normalizedFuel(value);
  return fuel.includes("diesel") || fuel.includes("gazole") ? "diesel" : "petrol";
}
function fuelSpeedTable(consumptionPer100: number, traffic: boolean): string {
  // HERE expects millilitres per metre. A user value of 6.5 L/100 km
  // corresponds to 0.065 ml/m. The curve keeps the user's real average as
  // calibration around 80-90 km/h, then varies it with speed/traffic.
  const profile = traffic
    ? [[10,2.10],[20,1.65],[30,1.34],[40,1.16],[50,1.04],[60,0.98],[70,0.96],[80,0.98],[90,1.04],[100,1.10],[110,1.18],[120,1.27],[130,1.37]]
    : [[10,1.55],[20,1.34],[30,1.20],[40,1.08],[50,1.00],[60,0.95],[70,0.93],[80,0.95],[90,1.00],[100,1.07],[110,1.15],[120,1.24],[130,1.34]];
  const base = consumptionPer100 / 100;
  return profile.map(([speed,multiplier]) => `${speed},${round(base * multiplier, 5)}`).join(",");
}
function distanceMeters(a: Point, b: Point): number {
  const rad = (value: number) => value * Math.PI / 180;
  const lat1 = rad(a.lat), lat2 = rad(b.lat);
  const dLat = lat2 - lat1;
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat/2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng/2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(Math.max(0, 1-h)));
}
function candidate(route: any, id: string, label: string, consumption: number, price: number): Candidate | null {
  const sections = Array.isArray(route?.sections) ? route.sections : [];
  if (!sections.length) return null;
  let meters = 0, seconds = 0, toll = 0, hereConsumption = 0;
  let hasHereConsumption = false;
  const points: Point[] = [];
  for (const section of sections) {
    meters += Number(section?.summary?.length ?? 0) || 0;
    seconds += Number(section?.summary?.duration ?? 0) || 0;
    const value = Number(section?.summary?.tolls?.total?.value ?? 0);
    if (Number.isFinite(value) && value > 0) toll += value;
    const sectionConsumption = Number(section?.summary?.consumption);
    if (Number.isFinite(sectionConsumption) && sectionConsumption >= 0) {
      hereConsumption += sectionConsumption;
      hasHereConsumption = true;
    }
    addPoints(points, section?.polyline);
  }
  if (meters <= 0 || seconds <= 0) return null;
  const km = meters / 1000;
  const energyQuantity = hasHereConsumption
    ? hereConsumption
    : km / 100 * consumption;
  const energyCost = energyQuantity * price;
  return {
    id, label, distance_km: round(km, 1), duration_minutes: round(seconds/60, 1),
    toll_eur: round(toll), energy_quantity: round(energyQuantity, 2),
    energy_cost_eur: round(energyCost), total_cost_eur: round(toll + energyCost), points,
  };
}
async function routeCandidates(
  origin: Point, destination: Point, apiKey: string, consumption: number, price: number, fuelType: unknown,
  options: { prefix: string; label: string; alternatives?: number; avoidTolls?: boolean; via?: Point[] },
): Promise<Candidate[]> {
  const url = new URL(HERE_ROUTE_URL);
  url.searchParams.set("transportMode", "car"); url.searchParams.set("routingMode", "fast");
  url.searchParams.set("origin", `${origin.lat},${origin.lng}`);
  url.searchParams.set("destination", `${destination.lat},${destination.lng}`);
  url.searchParams.set("return", "polyline,summary,tolls");
  url.searchParams.set("currency", "EUR"); url.searchParams.set("spans", "tollSystems");
  url.searchParams.set("tolls[summaries]", "total");
  url.searchParams.set("fuel[type]", hereFuelType(fuelType));
  url.searchParams.set("fuel[freeFlowSpeedTable]", fuelSpeedTable(consumption, false));
  url.searchParams.set("fuel[trafficSpeedTable]", fuelSpeedTable(consumption, true));
  url.searchParams.set("apiKey", apiKey);
  const alt = Math.max(0, Math.min(2, options.alternatives ?? 0));
  if (alt) url.searchParams.set("alternatives", String(alt));
  if (options.avoidTolls) url.searchParams.set("avoid[features]", "tollRoad");
  for (const p of options.via ?? []) url.searchParams.append("via", `${p.lat},${p.lng}`);
  let data: any;
  try {
    data = await fetchJson(url);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.startsWith("HERE_400") && !message.startsWith("HERE_422")) throw error;
    // HERE's empirical fuel model is currently beta. If the provider rejects
    // those optional parameters, preserve route/toll value with the simpler
    // distance-based consumption fallback instead of failing the feature.
    url.searchParams.delete("fuel[type]");
    url.searchParams.delete("fuel[freeFlowSpeedTable]");
    url.searchParams.delete("fuel[trafficSpeedTable]");
    data = await fetchJson(url);
  }
  const out: Candidate[] = [];
  const routes = Array.isArray(data?.routes) ? data.routes : [];
  for (let i=0; i<routes.length; i++) {
    const c = candidate(routes[i], `${options.prefix}_${i}`, i ? `${options.label} ${i+1}` : options.label, consumption, price);
    if (c) out.push(c);
  }
  return out;
}
function pointAt(points: Point[], f: number): Point | null {
  if (points.length < 3) return null;
  const segments: number[] = [];
  let total = 0;
  for (let i = 1; i < points.length; i += 1) {
    const length = distanceMeters(points[i-1], points[i]);
    segments.push(length);
    total += length;
  }
  if (total <= 0) return points[Math.floor(points.length * f)] ?? null;
  const target = total * Math.max(0, Math.min(1, f));
  let walked = 0;
  for (let i = 0; i < segments.length; i += 1) {
    walked += segments[i];
    if (walked >= target) return points[Math.min(points.length-2, Math.max(1, i+1))] ?? null;
  }
  return points[points.length-2] ?? null;
}
function dedupe(values: Candidate[]): Candidate[] {
  const map = new Map<string, Candidate>();
  for (const c of values) {
    const key = `${Math.round(c.distance_km*2)}:${Math.round(c.duration_minutes)}:${Math.round(c.toll_eur*2)}`;
    const old = map.get(key); if (!old || c.total_cost_eur < old.total_cost_eur) map.set(key, c);
  }
  return [...map.values()];
}
function pub(c: Candidate) {
  return {
    id:c.id,label:c.label,distance_km:c.distance_km,duration_minutes:c.duration_minutes,
    toll_eur:c.toll_eur,energy_quantity:c.energy_quantity,energy_cost_eur:c.energy_cost_eur,total_cost_eur:c.total_cost_eur,
  };
}
function navPoints(c: Candidate): Point[] {
  if (c.points.length < 6) return [];
  return [pointAt(c.points,.34),pointAt(c.points,.67)].filter((v): v is Point => v != null);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405,{success:false,error:"METHOD_NOT_ALLOWED"});
  const requestId = crypto.randomUUID();
  try {
    const apiKey = Deno.env.get("HERE_API_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!apiKey || !supabaseUrl || !anonKey || !serviceRole) {
      return json(503,{success:false,error:"SMART_TRIP_NOT_CONFIGURED",request_id:requestId});
    }
    const authorization = request.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) return json(401,{success:false,error:"AUTH_REQUIRED",request_id:requestId});
    const userClient = createClient(supabaseUrl, anonKey, {
      global:{headers:{Authorization:authorization}}, auth:{persistSession:false},
    });
    const admin = createClient(supabaseUrl, serviceRole,{auth:{persistSession:false}});
    const token = authorization.slice("Bearer ".length);
    const {data:authData,error:authError} = await userClient.auth.getUser(token);
    const user = authData?.user;
    if (authError || !user) return json(401,{success:false,error:"AUTH_REQUIRED",request_id:requestId});

    const body = await request.json().catch(()=>({}));
    const vehicleId = clean(body?.vehicle_id,80);
    const consumption = numberOf(body?.consumption_per_100);
    const price = numberOf(body?.energy_price);
    const maxDelay = numberOf(body?.max_extra_minutes);
    if (!vehicleId) return json(400,{success:false,error:"VEHICLE_REQUIRED",request_id:requestId});
    if (consumption == null || consumption<0.5 || consumption>35 || price == null || price<.05 || price>5 ||
        maxDelay == null || maxDelay<0 || maxDelay>60) {
      return json(400,{success:false,error:"INVALID_FINANCIAL_INPUT",request_id:requestId});
    }
    const {data:vehicle,error:vehicleError} = await admin.from("vehicles")
      .select("id,user_id,make,model,fuel_type").eq("id",vehicleId).maybeSingle();
    if (vehicleError || !vehicle || vehicle.user_id !== user.id) {
      return json(404,{success:false,error:"VEHICLE_NOT_FOUND",request_id:requestId});
    }
    if (isFullElectric(vehicle.fuel_type)) {
      return json(422,{success:false,error:"EV_NOT_SUPPORTED_V1",request_id:requestId});
    }

    const origin = await resolvePlace(body?.origin,apiKey,"Ma position");
    const destination = await resolvePlace(body?.destination,apiKey,"Destination");
    const fastest = await routeCandidates(origin,destination,apiKey,consumption,price,vehicle.fuel_type,{
      prefix:"FASTEST",label:"Trajet rapide",alternatives:2,
    });
    if (!fastest.length) throw new Error("NO_ROUTE");
    const baseline = fastest[0];
    const noToll = await routeCandidates(origin,destination,apiKey,consumption,price,vehicle.fuel_type,{
      prefix:"NO_TOLL",label:"Sans péage",alternatives:1,avoidTolls:true,
    });
    const all = [...fastest,...noToll];
    const ref = noToll[0];
    if (ref) {
      for (const h of [
        {fraction:.70,prefix:"HYBRID_70",label:"Sortie plus tôt"},
        {fraction:.85,prefix:"HYBRID_85",label:"Sortie proche destination"},
      ]) {
        const via = pointAt(ref.points,h.fraction); if (!via) continue;
        try {
          all.push(...await routeCandidates(origin,destination,apiKey,consumption,price,vehicle.fuel_type,{
            prefix:h.prefix,label:h.label,via:[via],
          }));
        } catch (_) {}
      }
    }
    const candidates = dedupe(all);
    const threshold = Math.max(MIN_SAVING_EUR,baseline.total_cost_eur*MIN_SAVING_RATIO);
    const eligible = candidates
      .filter(c=>c.id!==baseline.id)
      .map(c=>({c,delay:c.duration_minutes-baseline.duration_minutes,saving:baseline.total_cost_eur-c.total_cost_eur}))
      .filter(x=>x.delay<=maxDelay+.25 && x.saving>=threshold)
      .sort((a,b)=>Math.abs(b.saving-a.saving)<=1 ? a.delay-b.delay : b.saving-a.saving);
    const winner = eligible[0]?.c ?? baseline;
    const net = round(baseline.total_cost_eur-winner.total_cost_eur);
    const status = winner.id===baseline.id ? "BASELINE_BEST" : "SAVING_FOUND";
    return json(200,{
      success:true,status,request_id:requestId,method:"DETERMINISTIC_FINANCIAL_V1",consumption_model:"HERE_SPEED_TRAFFIC_CALIBRATED_WITH_DISTANCE_FALLBACK",
      origin,destination,
      vehicle:{id:vehicle.id,make:vehicle.make,model:vehicle.model,fuel_type:vehicle.fuel_type},
      baseline:pub(baseline),recommended:pub(winner),
      comparison:{
        extra_minutes:round(winner.duration_minutes-baseline.duration_minutes,1),
        extra_km:round(winner.distance_km-baseline.distance_km,1),
        toll_saving_eur:round(baseline.toll_eur-winner.toll_eur),
        energy_cost_delta_eur:round(winner.energy_cost_eur-baseline.energy_cost_eur),
        net_saving_eur:net,
        percent_saving:baseline.total_cost_eur>0?round(net/baseline.total_cost_eur*100,1):0,
      },
      navigation_waypoints:navPoints(winner),tested_routes:candidates.length,
      saving_threshold_eur:round(threshold),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    let code="SMART_TRIP_SERVICE_ERROR", status=500;
    if (message==="PLACE_REQUIRED" || message==="PLACE_NOT_FOUND") {code=message;status=400;}
    else if (message==="NO_ROUTE") {code="NO_ROUTE";status=404;}
    else if (message.startsWith("HERE_429")) {code="ROUTING_TEMPORARILY_BUSY";status=503;}
    else if (message.startsWith("HERE_401") || message.startsWith("HERE_403")) {code="ROUTING_CONFIGURATION_ERROR";status=503;}
    else if (message.startsWith("HERE_")) {code="ROUTING_SERVICE_ERROR";status=502;}
    else if (message.toLowerCase().includes("abort")) {code="ROUTING_TIMEOUT";status=504;}
    console.error("analyze-smart-trip",{
      request_id:requestId,code,
      internal_error:message.slice(0,240).replace(/apiKey=[^&\s]+/gi,"apiKey=[redacted]"),
    });
    return json(status,{success:false,error:code,request_id:requestId});
  }
});
