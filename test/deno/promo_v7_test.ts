import {assertEquals,assert} from "jsr:@std/assert@1.0.16";
import {amounts,validate,compatibility,type Offer,type Source} from "../../supabase/functions/promo-v7/semantic.ts";
const source:Source={operator:"AD",canonical_brand:"*",role:"OFFER_HUB",policy:"AUTO_HIGH_CONFIDENCE",trust:"PROFESSIONAL",url:"https://example.com/promos",source_status:"ACTIVE"};
const offer=(patch:Partial<Offer>={}):Offer=>({
 decision:"OFFER",title:"Forfait vidange",category:"MAINTENANCE",category_quote:"Forfait vidange",
 context:"CURRENT_VEHICLE",kind:"FROM_PRICE",benefit_quote:"à partir de 92€90",amount:92.9,amount_scope:"TOTAL",
 quantity:null,quantity_quote:"",product_brand:"",product_brand_quote:"",conditions:"Centres participants",conditions_quote:"Centres participants",
 starts_at:null,ends_at:"2026-12-31",date_quote:"jusqu'au 31 décembre 2026",vehicle_brand:"",models:[],excluded_models:[],model_quote:"",
 fuel_types:[],fuel_quote:"",age_min:null,age_max:null,age_quote:"",geographic_scope:"NATIONAL",geography_quote:"France",location_label:"France",eligibility_uncertain:false,reason:"",
 ...patch});
const text="Forfait vidange à partir de 92€90 jusqu'au 31 décembre 2026. Centres participants. France.";
const check=(o:Offer,t=text)=>validate({text:t,source},o,"2026-11-24");
Deno.test("French cents, grouped prices, tyre unit and percentages",()=>{
 assertEquals(amounts("92€90 / 14 280 € / 79,75 € / 50%"),[92.9,14280,79.75,50]);
});
Deno.test("Correct maintenance campaign has exact proofs",()=>assertEquals(check(offer()).state,"READY"));
Deno.test("Audit AD 92 euro truncation is rejected for automatic publication",()=>{
 assert(check(offer({amount:92})).reasons.includes("AMOUNT_UNPROVEN"));
});
Deno.test("Audit Eurorepar oil filter does not turn a service into spare parts",()=>{
 const o=offer({category:"PARTS",category_quote:"Forfait vidange avec filtre à huile"});
 assert(check(o,text+" Forfait vidange avec filtre à huile").reasons.includes("MAINTENANCE_CONFLICT"));
});
Deno.test("Audit Renault tyre rebate cannot be a vehicle purchase",()=>{
 const o=offer({category:"NEW_VEHICLE",category_quote:"achat de 4 pneus",context:"VEHICLE_PURCHASE",kind:"REIMBURSEMENT",benefit_quote:"140 € remboursés pour l'achat de 4 pneus",amount:140,models:["Clio"],model_quote:"Clio"});
 assert(check(o,text+" 140 € remboursés pour l'achat de 4 pneus. Clio").reasons.includes("VEHICLE_PURCHASE_PROOF_INVALID"));
});
Deno.test("Audit 50% fitting is not 50% on the whole tyre price",()=>{
 const t="Pneus Continental : 50% du montage offert. jusqu'au 31 décembre 2026. Centres participants. France.";
 const o=offer({title:"Pneus Continental",category:"TYRES",category_quote:"Pneus Continental",kind:"PERCENT",amount:50,benefit_quote:"50% du montage offert",amount_scope:"TOTAL"});
 assert(check(o,t).reasons.includes("MOUNTING_SCOPE_REQUIRED"));
 assertEquals(check({...o,amount_scope:"MOUNTING"},t).state,"READY");
});
Deno.test("Audit newsletter / virtual garage do not pass commercial gate",()=>{
 assert(check(offer({benefit_quote:"newsletter 5 € offert",amount:5}),text+" newsletter 5 € offert").reasons.includes("NON_PROMOTIONAL_CONTENT"));
 assertEquals(check(offer({decision:"NOT_OFFER"})).state,"REJECTED");
});
Deno.test("Audit Point S mon espace cannot identify Renault Espace",()=>{
 const o=offer({models:["Espace"],model_quote:"Créer mon espace personnel"});
 assert(check(o,text+" Créer mon espace personnel").reasons.includes("MODEL_GENERIC_WORD"));
});
Deno.test("Unknown fuel or age cannot be confirmed compatible",()=>{
 const o=offer({fuel_types:["electric"],age_min:3});
 assertEquals(compatibility(o,{brand:"Renault",model:"Zoe",fuel:null,age:4}),"CHECK");
 assertEquals(compatibility(o,{brand:"Renault",model:"Zoe",fuel:"diesel",age:4}),"NO");
 assertEquals(compatibility(o,{brand:"Renault",model:"Zoe",fuel:"electric",age:null}),"CHECK");
 assertEquals(compatibility(o,{brand:"Renault",model:"Zoe",fuel:"electric",age:2}),"NO");
});
Deno.test("Source URL is not the commercial identity; product scope remains distinct",()=>{
 const o=offer();
 const a=check(o),b=validate({text,source:{...source,url:"https://example.com/other"}},o,"2026-11-24");
 assertEquals(a.identity,b.identity);
 assert(a.identity!==check({...o,amount_scope:"PART"}).identity);
});
Deno.test("No invented dates, geography, or missing conditions",()=>{
 assert(check(offer({ends_at:"2026-12-30"})).reasons.includes("DATE_UNPROVEN"));
 assert(check(offer({ends_at:null})).reasons.includes("END_DATE_UNKNOWN"));
 assert(check(offer({conditions_quote:""})).reasons.includes("CONDITIONS_MISSING"));
 assert(check(offer({location_label:"Bourgogne"})).reasons.includes("GEOGRAPHY_UNPROVEN"));
});
Deno.test("Expired offer is rejected and future offer is not ready",()=>{
 assertEquals(validate({text,source},offer(),"2027-01-01").state,"REJECTED");
 const o=offer({starts_at:"2026-12-01",date_quote:"du 1 décembre 2026 jusqu'au 31 décembre 2026"});
 assert(check(o,text+" du 1 décembre 2026 jusqu'au 31 décembre 2026").reasons.includes("NOT_STARTED"));
});
Deno.test("Untrusted source cannot publish even with a valid extracted price",()=>{
 assert(validate({text,source:{...source,role:"DISCOVERY_ONLY"}},offer(),"2026-11-24").reasons.includes("SOURCE_NOT_PUBLICATION_ELIGIBLE"));
});
