# AutoClair — lot 1 : catalogue et découverte (19 octobre 2026)

Statut : **préparation non commercialisable**. Les catalogues et les textes de l’application viennent de `lib/features/premium/premium_catalog.dart`, qui est la source de vérité métier de ce lot.

## Produits

| Code interne | Offre | Prix TTC | Unités | Durée / règle | ID store | Vente |
|---|---|---:|---|---|---|---|
| premium_annual | Abonnement annuel | 29,99 € (cible, vérifier prix store) | Quotats document/360 à mesurer | 12 mois, renouvellement automatique selon Store | À confirmer | Fermée |
| analysis_small | Petit pack d’analyses documentaires | À chiffrer | À définir | Crédit acheté conservé indépendamment de Premium | À créer | Fermée |
| analysis_large | Grand pack d’analyses documentaires | À chiffrer | À définir | Crédit acheté conservé indépendamment de Premium | À créer | Fermée |
| vehicle360_single | Bilan 360 à l’unité | À chiffrer | 1 | Crédit acheté conservé indépendamment de Premium | À créer | Fermée |

**Pas d’offre mensuelle en V1**. Rien dans ce document ne vaut produit activé en boutique. Prix et quotas ponctuels : bloqués par l’absence de mesure validée des coûts réels (ticket 14). Une valeur absente n’est **jamais** « illimité ».

## Matrice des droits

| Fonction | Gratuit | Annuel | Achat ponctuel |
|---|---|---|---|
| Véhicules / carnet / échéances | Gestion et consultation, limite de véhicules à confirmer | Gestion et consultation, limite à confirmer | Aucun droit supplémentaire |
| Lecture documents / anciens résultats | Permanent | Permanent | Permanent |
| Nouvelle analyse documentaire | Quota gratuit à confirmer et protéger serveur | Quota annuel à confirmer | 1 crédit documentaire par traitement |
| Nouveau Bilan 360 | 1 essai complet par compte déjà implémenté | Quota annuel à confirmer ; ne pas promettre l’illimité | 1 crédit Bilan 360 |
| Analyse de pneus | Quota à confirmer | Quota à confirmer | Non inclus dans packs documentaires |
| Plans d’entretien / réactualisation | Quota à confirmer | Quota à confirmer | Non inclus |
| Assistant trajet | Quota API à confirmer | Quota API à confirmer | Non inclus |
| Assistance et litiges IA | Consignes critiques accessibles ; IA limitée | IA limitée par quota à confirmer | Non inclus |
| Identification, cote, CT/rappels, recherche et offres | Consultation disponible, appels facturés à plafonner | Idem avec limites documentées | Non inclus |

La liste complète et exploitable par code est dans `PremiumCatalog.featureRights`.

## Parcours découverte et recette

- Le premier Bilan 360 complet offert et son compteur existent déjà dans l’application/le backend : on les conserve.
- Le statut de l’essai ou du solde est affiché avant la génération ; à l’épuisement, le client est dirigé vers la même page d’offres contenant abonnement **et** packs.
- Les résultats précédemment générés restent consultables ; la lecture ne doit pas débiter un nouveau crédit.
- L’écran ancien « mensualité » et la promesse d’illimité sont retirés. Le module de restauration des achats existants reste accessible.
- **Aucun paiement nouveau** : `PremiumCatalog.checkoutEnabled = false` tant que le serveur ne garantit pas l’attribution, la consommation et les remboursements des crédits. Remettre à true seulement avec preuve des tickets 04-14.

### À fermer avant de déclarer le lot 1 terminé

1. Mesurer le coût unitaire des traitements réels et arbitrer les plafonds annuels, véhicules et essai documentaire (01, 02, 14).
2. Définir montants / volumes et IDs Store des 3 packs, source de vérité cohérente app/RevenueCat/backend (01, 04).
3. Installer le compteur documentaire et les droits serveur pour **tous** les endpoints coûteux (03, 10-13).
4. Exposer les soldes et l’achat effectif des packs indépendamment de Premium, avec idempotence (03-09).
5. Recette compte neuf, nouvelle analyse offerte, dépassement, achat ponctuel, reconnexion et ancien résultat sur une version signée.

Ne pas fusionner comme version commerciale tant que ces points restent ouverts.
