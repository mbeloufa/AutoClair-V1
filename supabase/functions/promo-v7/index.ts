import {createClient} from "npm:@supabase/supabase-js@2";
import { SYSTEM, RESPONSE_SCHEMA, VERSION, validate, type Offer, type Input, type Source } from "./semantic.ts";

const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{"Content-Type":"application/json"}});
const requireEnv=(k:string)=>{const v=Deno.env.get(k)?.trim();if(!v)throw Error("CONFIG_MISSING:"+k);return v;};
type Job={job_id:string;input_text:string;source:Source};
function record(v:unknown):v is Record<string,unknown>{return !!v&&typeof v==="object"&&!Array.isArray(v);}
function conforms(v:unknown,s:Record<string,unknown>):boolean{
 if(Array.isArray(s.enum)&&!s.enum.includes(v))return false;
 const kinds=Array.isArray(s.type)?s.type:[s.type];
 if(!kinds.some(k=>k==="null"?v===null:k==="array"?Array.isArray(v):k==="object"?record(v):k==="integer"?Number.isInteger(v):k==="number"?typeof v==="number"&&Number.isFinite(v):typeof v===k))return false;
 if(record(v)&&record(s.properties)){
  if(Object.keys(v).some(k=>!(k in (s.properties as Record<string,unknown>))))return false;
  for(const [k,def] of Object.entries(s.properties))if(!(k in v)||!record(def)||!conforms(v[k],def))return false;
 }
 if(Array.isArray(v)&&record(s.items))return v.every(x=>conforms(x,s.items as Record<string,unknown>));
 return true;
}
async function analyze(job:Job,key:string,model:string):Promise<{offers:Offer[];usage:unknown}>{
 const input:Input={text:job.input_text,source:job.source};
 const response=await fetch("https://api.openai.com/v1/responses",{
  method:"POST",headers:{Authorization:"Bearer "+key,"Content-Type":"application/json"},
  signal:AbortSignal.timeout(35000),
  body:JSON.stringify({model,store:false,max_output_tokens:6500,
   input:[{role:"system",content:SYSTEM},{role:"user",content:JSON.stringify(input)}],
   text:{format:{type:"json_schema",name:"promo_v7",strict:true,schema:RESPONSE_SCHEMA}}})
 });
 if(!response.ok){
  // Capture only allowlisted machine codes, never the provider error message.
  let code="";
  try {const body=await response.json();code=String(body?.error?.code??body?.error?.type??"");}catch(_){/* no body */}
  if(response.status===429){
    if(["insufficient_quota","billing_hard_limit_reached","billing_not_active"].includes(code))throw Error("AI_QUOTA_EXHAUSTED");
    if(code==="rate_limit_exceeded")throw Error("AI_RATE_LIMIT");
    throw Error("AI_HTTP_429");
  }
  if(response.status===401||response.status===403)throw Error("AI_AUTH_OR_ACCESS");
  throw Error("AI_HTTP_"+response.status);
 }
 const result=await response.json();
 if(result.status!=="completed")throw Error("AI_INCOMPLETE");
 const texts:string[]=[];
 for(const item of result.output??[])for(const c of item.content??[])if(c.type==="output_text"&&typeof c.text==="string")texts.push(c.text);
 if(texts.length!==1)throw Error("AI_OUTPUT_INVALID");
 const out:unknown=JSON.parse(texts[0]);
 if(!conforms(out,RESPONSE_SCHEMA)||!record(out)||!Array.isArray(out.offers)||out.offers.length>6)throw Error("AI_SCHEMA_INVALID");
 return {offers:out.offers as Offer[],usage:result.usage??null};
}
Deno.serve(async req=>{
 if(req.method!=="POST")return json({error:"METHOD_NOT_ALLOWED"},405);
 // Same trusted scheduler secret as legacy collector, checked before any AI call.
 const secret=req.headers.get("x-sync-secret")?.trim()??"";
 if(secret.length<32)return json({error:"UNAUTHORIZED"},401);
 try{
  const db=createClient(requireEnv("SUPABASE_URL"),requireEnv("SUPABASE_SERVICE_ROLE_KEY"),{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:valid,error:authError}=await db.rpc("validate_commercial_offer_sync_secret",{p_candidate:secret});
  if(authError||valid!==true)return json({error:"UNAUTHORIZED"},401);
  // No schedule and no publication. A trusted operator may run a single job
  // explicitly while shadow automation is disabled. The SQL global cap still applies.
  const pilot=req.headers.get("x-promo-v7-pilot")==="1";
  if(!pilot&&Deno.env.get("PROMO_V7_SHADOW_ENABLED")!=="true")return json({status:"DISABLED"});
  const model=Deno.env.get("PROMO_V7_MODEL")?.trim()||requireEnv("OPENAI_MODEL");
  const key=requireEnv("OPENAI_API_KEY");
  if(!pilot){
    const {data:failures,error:healthError}=await db.from("promo_v7_shadow_jobs").select("error_code")
      .in("error_code",["AI_QUOTA_EXHAUSTED","AI_HTTP_429","AI_RATE_LIMIT","AI_AUTH_OR_ACCESS"])
      .gte("created_at",new Date(Date.now()-6*3600000).toISOString()).limit(1);
    if(healthError)throw Error("AI_HEALTH_CHECK_FAILED");
    if(failures?.length)return json({status:"PROVIDER_COOLDOWN"});
  }
  const {data,error}=await db.rpc("promo_v7_claim_shadow",{p_engine:VERSION,p_model:model});
  if(error)throw Error("QUEUE_CLAIM_FAILED");
  if(!data||!Array.isArray(data)||data.length===0)return json({status:"NO_JOB_OR_BUDGET"});
  const job=data[0] as Job;
  try{
   const result=await analyze(job,key,model);
   const outcomes=result.offers.map(o=>validate({text:job.input_text,source:job.source},o));
   const {error:saveError}=await db.rpc("promo_v7_finish_shadow",{p_job:job.job_id,p_results:outcomes,p_usage:result.usage,p_error:null});
   if(saveError)throw Error("RESULT_SAVE_FAILED");
   return json({status:"SHADOW_ONLY",job_id:job.job_id,ready:outcomes.filter(o=>o.state==="READY").length,review:outcomes.filter(o=>o.state==="REVIEW").length,rejected:outcomes.filter(o=>o.state==="REJECTED").length});
  }catch(e){
   const code=e instanceof Error?e.message.slice(0,100):"UNKNOWN";
   // Never persist provider bodies, keys, or prompts in error messages.
   const safe=/^[A-Z0-9_]+$/.test(code)?code:"ANALYSIS_FAILED";
   const {error:failed}=await db.rpc("promo_v7_finish_shadow",{p_job:job.job_id,p_results:[],p_usage:null,p_error:safe});
   if(failed)console.error("PROMO_V7_JOB_NOT_SETTLED",job.job_id);
   return json({status:"REVIEW",error:safe},503);
  }
 }catch(e){
  console.error("PROMO_V7_INFRASTRUCTURE_ERROR",e instanceof Error?e.message.split(":")[0]:"UNKNOWN");
  return json({error:"PROMO_V7_UNAVAILABLE"},503);
 }
});
