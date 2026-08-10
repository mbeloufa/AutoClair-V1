# AutoClair V1 commercialisable — périmètre produit public

Ce document verrouille le périmètre visible de la V1 commerciale.

## Parcours publics retenus

1. Mon véhicule & carnet
   - carnet d’entretien intelligent ;
   - événements, historique et justificatifs ;
   - prochaines échéances et notifications ;
   - identification par immatriculation ;
   - rappels constructeur ;
   - promotions personnalisées ;
   - tableau de bord véhicule ;
   - Bilan AutoClair 360.

2. Analyser un document
   - facture ;
   - devis ;
   - contrôle technique ;
   - bon de commande / vente ;
   - contrat de location, LOA, LLD ;
   - assurance ;
   - autres documents automobiles pertinents.

3. Autour de moi
   - parking ;
   - stations-service ;
   - bornes de recharge ;
   - contrôle technique.

4. Achat / vente
   - analyse d’annonce ;
   - assistant / checklist d’achat ;
   - génération d’annonce ;
   - préparation de vente.

5. Offres automobiles
   - offres après-vente personnalisées ;
   - offres commerciales de vente automobile.

## Règle d’exclusion

Les anciens assistants autonomes créés avant la définition de cette V1 ne
doivent plus être exposés comme fonctions commerciales indépendantes :
panne/imprévu, accident, vol, prévision de risque, inspection autonome,
préparation de trajet, immobilisation, préparation CT autonome, visite garage,
suivi pneus autonome, suivi batterie autonome, niveaux, éclairage, freinage,
carrosserie, restitution LOA/LLD, conformité, révision assurance, budget
autonome, optimiseur carburant/recharge, éco-conduite, etc.

Certaines notions restent naturellement utilisées DANS les parcours retenus.
Exemples :
- batterie, pneus, freins et panne peuvent rester des événements/échéances du carnet ;
- LOA et LLD restent des types de documents analysables ;
- carburant et recharge restent dans « Autour de moi » ;
- budget reste un indicateur du tableau de bord véhicule.

Le code historique peut rester dans le dépôt pour éviter une suppression
destructive, mais il ne doit plus apparaître dans la navigation publique V1.
Les anciennes routes sont redirigées vers le hub V1 afin d’éviter les accès
par anciens liens profonds.
