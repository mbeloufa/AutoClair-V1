# AUTOCLAIR — V1 commerciale : journal de mise en œuvre et de recette

Référence : feuille de route 19 octobre 2026, 36 tickets et 8 lots. Android français en premier ; iOS distinct.

## Statut global

**NON VALIDÉ POUR PRODUCTION / AUCUNE FUSION AUTOMATIQUE.**
Implémentation sur la branche `lot1-offres-decouverte-v1-20261019`. La production Supabase n'a pas reçu les nouvelles migrations ni les fonctions commerciales. La vente reste désactivée. Les tests Flutter CI ne remplacent pas les tests d'achats sur piste Play et les tests physiques.

Légende : `C` = code préparé et revu statiquement ; `P` = partiel ; `E` = configuration externe/recette nécessaire ; `V` = vérification fonctionnelle requise.

| Ticket | Lot | Avancement constaté | Reste à fermer |
|---:|---:|---|---|
| 01 | Offre | P — catalogue unique annuel 29,99 € TTC, 3 packs distincts | Coût réel, volumes, prix packs, identifiants stores |
| 02 | Offre | P — matrice explicite par fonction | Quotas exacts, véhicules, période, assistants coûteux |
| 03 | Offre | P — essai Bilan 360 existant, essai documentaire SQL préparé, parcours vers packs | Migration, activation, tests résultat/achat/consultation |
| 04 | Achats | E — instructions produit/store et webhook préparés | Configuration Google Play/RevenueCat et secrets |
| 05 | Achats | C/E — achats ponctuels Flutter distincts de Premium | Produit Play actif et essai sur piste Play |
| 06 | Achats | C/E — tables transactions, lots, idempotence, RLS, RPC | Migration en environnement de validation et essais concurrents |
| 07 | Achats | C/E — webhook avec autorisation et vérification, révocation | Déploiement, RTDN/notifications stores, événements hors ordre testés |
| 08 | Achats | P — page de compte, soldes, restauration, gestion Store | Crédits confirmés sur téléphone, suivi de renouvellement |
| 09 | Achats | V — suite de recette décrite | Achats différés, doubles, refus, remboursements, deux comptes |
| 10 | Coûts | P — gardien serveur documentaire conditionnel | Étendre **chaque** endpoint payant et activer enforcement |
| 11 | Coûts | C/E — lot réservé atomiquement, clé stable | Tests de concurrence sur vraie base de test |
| 12 | Coûts | P — réconciliation après erreur documents, TTL SQL | Rattrapage automatique, uploads interrompus, réservations fantômes |
| 13 | Coûts | P — magic bytes, 15 Mo/fichier, max 5 fichiers, PDF <= 30 pages | Tests vrais PDF, limites de stockage / fréquence |
| 14 | Coûts | P — échantillon réel 12 analyses documents, tokens | Prix fournisseur confirmés, alertes et plafond budget |
| 15 | Compte | C/V — formulaire nouveau mot de passe + deep link | Flux email complet et lien expiré sur deux téléphones |
| 16 | Compte | E — redirection définie | SMTP/domaine, URL Supabase autorisées, délivrabilité |
| 17 | Compte | P — inventaire/purge de 3 buckets | Déployer/tester dossiers interrompus, sauvegardes, purge légale |
| 18 | Compte | P — annulation rappels locaux à déconnexion/suppression | Brouillons et préférences par compte, déconnexion multi-utilisateur |
| 19 | Qualité | V — mécanismes déjà présents | Corpus scan/import/analyse/carnet réels, reprise et dédoublonnage |
| 20 | Qualité | V — garde-fou méthodologique | Corpus annoté, erreurs critiques, justesse dates/montants |
| 21 | Qualité | V — modules existants | Bilans, pneus, trajets, entretien, litiges, assistance, cote |
| 22 | Qualité | C/V — clic rappel, route et lancement à froid préparés | Android réel, permission refusée, sessions, rappels supprimés |
| 23 | Qualité | V — services de proximité existants | Fournisseurs, GPS désactivé, valeurs manquantes, liens |
| 24 | Qualité | V — UI à qualifier | Petits écrans, réseaux hors ligne, accessibility |
| 25 | Sécurité | P — nouveaux registres RLS / service_role ; audit initial | Audit complet des autres endpoints, deux comptes, alertes |
| 26 | Sécurité | E — déploiement staged uniquement | Isolement environnement, backup stockage + DB, test restauration |
| 27 | Conformité | E — parcours client identifié | Informations vendeur, CGU/CGV/privée approuvées et publiées |
| 28 | Conformité | P — dialogue IA documents avant transmission | Même transparence dans tous assistants + politique générale |
| 29 | Conformité | P — formulaire de support enregistré en base | Vrai canal traité, export/droits, page web de suppression |
| 30 | Conformité | C/V — signalement résultat dans l'application + RLS | Déployer et contrôler délai de triage/support |
| 31 | Conformité | E — liste des fournisseurs à auditer | Licences, attribution, quotas, droits sur médias |
| 32 | Conformité | P — nom AutoClair Android + iOS | Icône launcher, écran de lancement, assets/licences |
| 33 | Publication | P — release ne signe plus avec debug ; clés externes | Keystore production, AAB réel, 16 Ko, revue Play |
| 34 | Publication | E — éléments attendus détaillés | Console Play, compte marchand, captures, Data safety |
| 35 | Publication | P — GitHub CI Flutter et tests contrats | Test release signé + 14 scénarios de recette |
| 36 | Publication | E — trames d'incident à remplir | Support, surveillance, tableau coût, playbook incident testé |

## Déploiement sûr, dans cet ordre

1. **Ne pas activer les ventes** tant que les prix et volumes ne sont pas confirmés à partir du coût réel par endpoint et du nombre de clients gratuits.
2. Faire une sauvegarde/restauration d'essai du **PostgreSQL et Storage**, sur environnement isolé. Identifier la version source/secret.
3. Appliquer les migrations **sur cet environnement de test** : `20261019000100_commercial_ledger_v1.sql` puis `20261019000200_feedback_v1.sql`. Vérifier politiques RLS, contraintes, RPC et double événement.
4. Déployer les functions `revenuecat-commercial-webhook` (**verify_jwt=false**, secret d'authentification vérifié dans son code) et `sync-commercial-purchases` (**verify_jwt=true**), ainsi que `analyze-document` et `delete-account` modifiées. Aucune de ces modifications n'a été appliquée à la production par le seul commit GitHub.
5. Configurer les variables serveur : `REVENUECAT_SECRET_API_KEY` et `REVENUECAT_WEBHOOK_AUTHORIZATION` (valeur exactement égale au header Authorization émis par RevenueCat). Ne pas versionner les secrets.
6. Créer et approuver dans Google Play et RevenueCat les produits **annuel** et **consommables séparés**. Relier les identifiants approuvés aux lignes `commercial_products`. Les packs n'appartiennent pas à l'entitlement `premium`.
7. Valider les achats en attente, annulation, remboursements, événements dupliqués et désordonnés, récupération d'achat après coupure, changement d'appareil et changement de compte.
8. Activer les lignes produits en base uniquement après essais et mise à jour du catalogue Flutter. Activer le contrôle documentaire avec `COMMERCIAL_QUOTAS_ENFORCED=true` seulement après migration et recette. Étendre ce contrôle à **toutes** les fonctions coûteuses avant lancement.
9. Réconcilier les comptes existants avant bascule de quotas, sans confiscation des résultats ou crédits déjà acquis.
10. Signer un AAB production, le diffuser via Play en test, enregistrer version et SHA, clôturer ticket 35, puis publier progressivement.

## Contrats commerciaux à décider après coût

Abonnement annuel = 29,99 € TTC cible. Les 3 packs sont volontairement non commercialisés : prix, quantités et IDs Store sont indéterminés. `commercial_products.active=false` et `PremiumCatalog.checkoutEnabled=false` sont des protections explicites. Les champs `quantity=1` inscrits dans les lignes de packs documentaires de **migration de préparation** sont des valeurs techniques provisoires et NE SONT PAS le volume commercial approuvé. Le produit Bilan 360 est défini à 1 unité.

**Mesure existante :** 12 documents complétés en base, moyenne 4 987 tokens d'entrée et 1 921 tokens de sortie par document (consultation agrégée du 19/10/2026). Le modèle relevé est `gpt-5.6-terra`; aucune grille tarifaire vérifiée ne permet d'en déduire des euros fiables ici. Mesurer également scanner, stockage, identification, plans, pneus, trajets, cote et actualisations : le coût d'un document n'est pas le coût d'une année client.

## Configuration du mot de passe oublié

Dans Supabase Auth > URL Configuration, inscrire `autoclair://auth/reset` dans les Redirect URLs autorisées, configurer l'envoi SMTP de production. Vérifier les deux OS sur de vrais appareils. Ne jamais publier une URL de développement.

## Signature Android et sécurité des clés

Créer localement **android/key.properties**, non versionné, avec :
```properties
storeFile=/CHEMIN/ABSOLU/PRIVE/upload-keystore.jks
storePassword=VALEUR_PRIVEE
keyAlias=upload
keyPassword=VALEUR_PRIVEE
```
Sauvegarder le keystore hors du dépôt. Créer la clé seulement via procédure sécurisée. La compilation release échoue expressément lorsque les paramètres de signature manquent ; elle ne revient jamais aux clés debug. Configurer ensuite Play App Signing, tester le paquet installé depuis Play.

## Triage des retours clients

Le signalement est stocké dans `public.app_feedback`, sans joindre les fichiers personnels. Un opérateur autorisé doit traiter `status='new'`, répondre au client via un support réellement surveillé et escalader tout signalement `dangerous`. La table ne constitue pas à elle seule une boîte support opérationnelle ni un engagement de réponse.

## Critère de mise en production

Aucun défaut critique ouvert ; aucun achat non délivré, crédit falsifiable ou données croisées ; recettes sur même build signé / même backend / mêmes produits ; vérification des mentions légales, fournisseurs, sauvegardes, chaîne de support et compatibilité Play. Le feu vert nécessite la fermeture **documentée** des 36 tickets.
