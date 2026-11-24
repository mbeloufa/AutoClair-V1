/// <reference lib="dom" />
import { parseHTML } from "npm:linkedom@0.18.12";
const normalize=(s:string)=>s.normalize("NFKD").replace(/\p{M}/gu,"").toLowerCase().replace(/[’‘]/g,"'").replace(/\s+/g," ").trim();

// Read HTML already obtained by the existing allowlisted, robots-aware crawler.
// DOM parsing does not execute scripts, fetch resources, or follow arbitrary links.
export type RawCard={text:string;heading:string};
const promo=/(?:\d[\d\s.,]*\s*(?:€|%)|\b(?:offert|offerte|gratuit|gratuite|rembours|remise|reduction)\b)/i;
const subject=/\b(?:entretien|vidange|revision|pneu|pneus|pneumatique|frein|batterie|climatisation|pare.brise|carrosserie|controle technique|essuie.glace|distribution|accessoire|vehicule|voiture|loyer|loa|lld|financement|assurance|garantie|reprise|prix|forfait)\b/i;
const clean=(s:string)=>s.replace(/\s+/g," ").trim();
// Preserve boundaries between DOM headings, paragraphs and adjacent blocks.
function visibleText(node:{nodeType:number;textContent:string|null;childNodes:ArrayLike<Node>}):string {
 if(node.nodeType===3)return node.textContent??"";
 return Array.from(node.childNodes).map(visibleText).join(" ");
}
const bad=/^(?:menu|accueil|en savoir plus|prendre rendez.vous|se connecter|inscription|newsletter|offres d'emploi|mon espace|votre espace|garage virtuel)$/i;
export function isolateRawCards(html:string):RawCard[]{
 if(!html||html.length>3_000_000)return [];
 const {document}=parseHTML(html) as unknown as {document:Document};
 for(const e of document.querySelectorAll("script,style,noscript,nav,header,footer,aside,form,template,[role=navigation],[role=banner],[role=contentinfo],[aria-hidden=true], [class*=cookie], [class*=newsletter], [id*=cookie], [id*=newsletter]"))e.remove();
 const found:Array<{node:Element;card:RawCard}>=[];
 const all=document.querySelectorAll("article,section,li,div[class],div[id],[itemtype*='Offer']");
 for(const el of Array.from(all).slice(0,4500)){
  const hint=normalize((el.getAttribute("class")??"")+" "+(el.getAttribute("id")??""));
  if(["div","section","li"].includes(el.tagName.toLowerCase())&&!/offer|offre|promo|campaign|deal|card|teaser|product|produit|tile|forfait|operation|reduction|advantage/.test(hint)&&!el.hasAttribute("itemtype"))continue;
  const headings=Array.from(el.querySelectorAll("h1,h2,h3,h4,h5,h6"));
  if(headings.length!==1)continue; // multiple headings usually mean multiple offers or a landing page
  const heading=clean(headings[0].textContent??"");
  if(heading.length<5||heading.length>180||bad.test(normalize(heading)))continue;
  const t=clean(visibleText(el));
  if(t.length<18||t.length>1900||!promo.test(normalize(t))||!subject.test(normalize(t)))continue;
  found.push({node:el as unknown as Element,card:{text:t,heading}});
 }
 // The most local valid card wins; a parent must not swallow two independent offers.
 const leaf=found.filter(x=>!found.some(y=>x!==y&&x.node.contains(y.node)));
 const seen=new Set<string>();const result:RawCard[]=[];
 for(const {card} of leaf){
  const k=normalize(card.text);
  if(!seen.has(k)){seen.add(k);result.push(card);}
  if(result.length>=24)break;
 }
 return result;
}
