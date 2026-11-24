import {assertEquals,assert} from "jsr:@std/assert@1.0.16";
import {isolateRawCards} from "../../supabase/functions/sync-commercial-offers/raw_cards.ts";

Deno.test("Promo DOM: isolate each of two promotions, ignore navigation and footer",()=>{
 const html="<html><body><nav><div class='promo-card'><h2>Entretien</h2>Newsletter 5 € offert</div></nav><main><section class='offers'><article class='promo-card'><h2>Forfait vidange</h2><p>À partir de 92€90, centres participants.</p></article><article class='promo-card'><h2>Pneus Continental</h2><p>50% du montage offert.</p></article></section></main><footer><div class='promo-card'><h2>Devis gratuit</h2>Nos services entretien auto</div></footer></body></html>";
 const cards=isolateRawCards(html);
 assertEquals(cards.length,2);
 assert(cards[0].text.includes("92€90"));
 assert(!cards[0].text.includes("Continental"));
 assert(cards[1].text.includes("50%"));
 assert(cards.every(c=>!c.text.includes("Newsletter")));
});
Deno.test("Promo DOM: generic navigation and menus do not create cards",()=>{
 const html="<main><div class='promo-card'><h2>Prendre rendez-vous</h2><p>Garage virtuel, entretien 100% gratuit</p></div><form><div class='offer'><h2>Entretien</h2>5 € offert newsletter</div></form></main>";
 assertEquals(isolateRawCards(html),[]);
});
Deno.test("Promo DOM: exact repeated cards on same page are deduplicated",()=>{
 const card="<article><h2>Entretien vidange</h2><p>Forfait à partir de 99 €</p></article>";
 assertEquals(isolateRawCards("<html><body>"+card+card+"</body></html>").length,1);
});
