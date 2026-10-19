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
| 06 | Achats | C/E — tables transactions, lots, idempotence, RLS, RPC ; tests PostgreSQL isolés réussis | Essais concurrents et transactions Store réelles |
| 07 | Achats | C/E — webhook : renouvellements annuels idempotents, révocation, droits à vie préservés | Déploiement, vrais webhooks Google Play et événements hors ordre |
| 08 | Achats | P — page de compte, soldes, restauration, gestion Store | Crédits confirmés sur téléphone, suivi de renouvellement |
| 09 | Achats | V — suite de recette décrite | Achats différés, doubles, refus, remboursements, deux comptes |
| 10 | Coûts | P — compteur documents / Bilan 360 et limites par jour/année sur 11 usages API ; tests unitaires Deno du garde-fou | Activer les 3 drapeaux indépendants et faire les essais de charge sur backend réel |
| 11 | Coûts | C/E — réservations atomiques, déduplication / double essai et période annuelle vérifiés par PostgreSQL isolé | Test de concurrence simultanée et panne réseau sur environnement Supabase de préproduction |
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
3. Appliquer les **quatre migrations** dans l'ordre : `20261019000100_commercial_ledger_v1.sql`, `20261019000200_feedback_v1.sql`, `20261019000300_commercial_ai_rate_limits_v1.sql`, `20261019000400_commercial_maintenance_jobs.sql`. Les tests PostgreSQL automatisés ont vérifié cet ordre sur un conteneur isolé ; il reste la recette sur une instance Supabase dédiée.
4. Déployer les functions `revenuecat-commercial-webhook` (**verify_jwt=false**, secret d'authentification vérifié dans son code) et `sync-commercial-purchases` (**verify_jwt=true**), ainsi que `analyze-document` et `delete-account` modifiées. Aucune de ces modifications n'a été appliquée à la production par le seul commit GitHub.
5. Configurer les variables serveur : `REVENUECAT_SECRET_API_KEY` et `REVENUECAT_WEBHOOK_AUTHORIZATION` (valeur exactement égale au header Authorization émis par RevenueCat). Ne pas versionner les secrets.
6. Créer et approuver dans Google Play et RevenueCat les produits **annuel** et **consommables séparés**. Relier les identifiants approuvés aux lignes `commercial_products`. Les packs n'appartiennent pas à l'entitlement `premium`.
7. Valider les achats en attente, annulation, remboursements, événements dupliqués et désordonnés, récupération d'achat après coupure, changement d'appareil et changement de compte.
8. Activer les lignes produits en base uniquement après essais. Basculer séparément `commercial_settings.document_credits_enabled`, `vehicle360_credits_enabled`, `other_credits_enabled` depuis **false**, après migration, réconciliation des droits existants et tests des 11 catégories API. Ne passer `sales_enabled=true` qu'une fois tous les garde-fous activés et la QA Store réussie.
9. Réconcilier les comptes existants avant bascule de quotas, sans confiscation des résultats ou crédits déjà acquis.
10. Signer un AAB production, le diffuser via Play en test, enregistrer version et SHA, clôturer ticket 35, puis publier progressivement.

## Contrats commerciaux à décider après coût

Abonnement annuel = **29,99 € TTC cible** (20 analyses documentaires + 5 Bilans 360 proposés, à vérifier économiquement). Hypothèses de packs dans le code : **5 documents / 3,99 €**, **15 documents / 8,99 €**, **1 Bilan 360 / 4,99 €**. Ces tarifs et quantités sont **provisoires, non approuvés et non vendus**. Les produits SQL restent `active=false`, sans identifiant Store ; `commercial_settings.sales_enabled=false` interdit toute mise en vente. Les droits acquis par achat ponctuel demeurent distincts des crédits d'abonnement.

**Mesure existante :** 12 documents complétés en base, moyenne 4 987 tokens d'entrée et 1 921 tokens de sortie par document (consultation agrégée du 19/10/2026). Le modèle relevé est `gpt-5.6-terra`; aucune grille tarifaire vérifiée ne permet d'en déduire des euros fiables ici. Mesurer également scanner, stockage, identification, plans, pneus, trajets, cote et actualisations : le coût d'un document n'est pas le coût d'une année client.


## Vérifications de facturation et anti-abus — 19 octobre 2026

- CI PostgreSQL : migration complète sur instance de test éphémère, tests de déduplication des achats, mise en réserve/consommation/libération, remboursements enregistrés avant l'achat, RLS, premier essai, cycle Premium idempotent et budget annuel.
- CI Deno : typage des fonctions Edge et tests du garde-fou `requireCommercialBudget` (refus sans politique, quotas épuisés, fonctionnalité absente, identifiant de requête généré côté serveur).
- Correctif supplémentaire : le nouveau premier Bilan 360 reconnaît une demande d'essai **déjà inscrite dans `vehicle_report_credit_events`**, même si le Bilan n'a pas été généré.
- Correctif supplémentaire : l'identifiant du cycle d'abonnement utilise la date d'achat/renouvellement validée par RevenueCat, **sans date d'expiration** ; une prolongation de grâce actualise la fin des droits sans doubler les unités.
- Le webhook RevenueCat se charge également de créer/révoquer les crédits annuels sans imposer au client de rouvrir AutoClair. Les crédits ponctuels achetés ne sont pas révoqués à l'expiration de l'abonnement.
- Les limites des 11 catégories de services coûteux sont définies dans `20261019000300_commercial_ai_rate_limits_v1.sql` et ne remplacent **pas** les crédits documentaires ou Bilans 360 : elles protègent l'exploitation des autres API (pneus, litiges, trajets, assistance, entretien, identification, cote, parking).
- **Non testé** : facturation avec de vrais produits Store, transfert/alias RevenueCat, achat différé, réponse aux remboursements réels, quota en charge concurrente sur Supabase hébergé.

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
