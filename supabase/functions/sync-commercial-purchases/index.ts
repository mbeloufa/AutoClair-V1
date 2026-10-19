import { createClient } from "npm:@supabase/supabase-js@2";

const json=(status:number,body:unknown)=>new Response(JSON.stringify(body),{
 status,headers:{"Content-Type":"application/json","Cache-Control":"no-store"},
});
type AnyMap=Record<string,unknown>;
const object=(x:unknown):AnyMap=>x && typeof x==="object" && !Array.isArray(x)?x as AnyMap:{};
const storeOf=(x:unknown):string|null=>{
 const value=String(x??"").toUpperCase();
 if(value==="PLAY_STORE")return "play_store";
 if(value==="APP_STORE")return "app_store";
 if(value==="AMAZON")return "amazon";
 if(value==="STRIPE")return "stripe";
 if(value==="TEST_STORE")return "test";
 return null;
};
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return json(200,{ok:true});
 if(req.method!=="POST")return json(405,{error:"METHOD_NOT_ALLOWED"});
 const supabaseUrl=Deno.env.get("SUPABASE_URL");
 const serviceRole=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 const rcKey=Deno.env.get("REVENUECAT_SECRET_API_KEY");
 if(!supabaseUrl||!serviceRole||!rcKey)return json(503,{error:"BILLING_UNAVAILABLE"});
 const token=(req.headers.get("Authorization")??"").replace(/^Bearer /,"");
 if(!token)return json(401,{error:"AUTH_REQUIRED"});
 const admin=createClient(supabaseUrl,serviceRole,{auth:{persistSession:false}});
 const {data:{user},error:userError}=await admin.auth.getUser(token);
 if(userError||!user)return json(401,{error:"AUTH_REQUIRED"});
 try{
  const response=await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user.id)}`,
  {headers:{Authorization:`Bearer ${rcKey}`,Accept:"application/json"}});
  if(!response.ok)return json(503,{error:"REVENUECAT_RETRY"});
  const subscriber=object(object(await response.json()).subscriber);
  const nonSubs=object(subscriber.non_subscriptions);
  const {data:products,error:productError}=await admin.from("commercial_products")
   .select("code,store_product_id").eq("active",true).eq("kind","consumable");
  if(productError) return json(503,{error:"CATALOG_UNAVAILABLE"});
  let linked=0;
  for(const product of products??[]){
    const receipts=nonSubs[product.store_product_id];
    if(!Array.isArray(receipts))continue;
    for(const item of receipts.slice(0,100)){
      const receipt=object(item),store=storeOf(receipt.store);
      const transactionId=String(receipt.id??receipt.transaction_id??"");
      if(!store||!transactionId)continue;
      if(store==="test" && Deno.env.get("COMMERCIAL_ALLOW_SANDBOX_PURCHASES")!=="true")
        continue;
      const purchasedDate=typeof receipt.purchase_date==="string"?
        receipt.purchase_date:new Date().toISOString();
      const {error}=await admin.rpc("commercial_grant_verified_purchase",{
        p_user_id:user.id,p_store:store,p_transaction_id:transactionId,
        p_product_code:product.code,
        p_environment:store==="test"?"SANDBOX":"PRODUCTION",
        p_purchased_at:purchasedDate,
      });
      if(error)throw new Error("RECOVERY_WRITE_FAILED");
      linked++;
    }
  }
  const {data:balances,error:balanceError}=await admin
    .from("commercial_credit_lots")
    .select("kind,source,units_total,units_reserved,units_used,expires_at,revoked_at")
    .eq("user_id",user.id);
  if(balanceError)throw new Error("RECOVERY_BALANCE_FAILED");
  const result:Record<string,Record<string,number>>={};
  for(const item of balances??[]){
    if(item.revoked_at)continue;
    if(item.expires_at&&new Date(item.expires_at)<=new Date())continue;
    const itemKind=String(item.kind);
    const source=String(item.source);
    result[itemKind]??={};
    const available=item.units_total-item.units_used-item.units_reserved;
    result[itemKind][source]=(result[itemKind][source]??0)+available;
  }
  return json(200,{success:true,recovered:linked,balances:result});
 }catch(error){
  console.error("Commercial purchase reconciliation failed",
    error instanceof Error?error.message:"unknown");
  return json(503,{error:"SYNC_PENDING"});
 }
});
