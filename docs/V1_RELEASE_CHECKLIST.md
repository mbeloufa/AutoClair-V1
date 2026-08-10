# AutoClair V1 — Checklist finale de commercialisation

Date de référence : 10 août 2026.

Ce document clôture les lots fonctionnels de la V1. Il distingue volontairement :
- la qualification du code AutoClair ;
- les prérequis techniques de publication ;
- les services externes qui doivent encore être activés ;
- les contrôles humains avant ouverture au public.

## 1. Ce que le Lot 12 considère comme qualifié

Le Lot 12 valide automatiquement :
- `flutter analyze` ;
- les tests ciblés des fonctions commerciales principales ;
- la suite complète `flutter test` ;
- un APK debug ;
- une tentative de génération Android App Bundle en release ;
- l'absence de modifications Git parasites ;
- la présence des briques V1 installées dans les Lots 8 à 11 ;
- l'absence du secret d'identification par immatriculation dans le client Flutter ;
- les principales fonctions Edge Supabase lorsqu'elles sont vérifiables en lecture seule.

## 2. Ce que le Lot 12 ne doit pas simuler

Une application n'est pas déclarée publiable si un élément extérieur manque.

Les points suivants restent des prérequis réels :
- compte Google Play Console ;
- compte Apple Developer / App Store Connect ;
- signature Android de production et conservation sécurisée de la clé ;
- compilation et essai iOS sur un Mac avec une version de Xcode conforme ;
- fournisseur d'identification par immatriculation et secret serveur si cette fonction doit être proposée ;
- fournisseur de paiement réel pour abonnement / achats à l'unité ;
- restauration des achats et gestion des échecs de paiement avec ce fournisseur ;
- prix et produits configurés dans les stores ;
- politique de confidentialité et informations légales publiées ;
- formulaires de confidentialité / sécurité des données des stores ;
- captures, description, icône, support et métadonnées des fiches stores ;
- tests finaux sur appareils physiques.

## 3. Paiement et freemium

La V1 possède une base de contrôle d'accès pour le Bilan AutoClair 360 :
- essai gratuit réel ;
- entitlement `vehicle_360` ;
- crédits ;
- paywall explicatif.

Cette base ne remplace pas un fournisseur de paiement.

Avant une commercialisation payante, il faut brancher un fournisseur compatible avec les règles des stores, puis relier les achats réels aux entitlements/crédits AutoClair.

Il faut également vérifier la couverture commerciale de toutes les fonctions IA coûteuses. Une fonction IA non couverte par une limite ou un achat peut générer un coût d'exploitation non maîtrisé.

## 4. Identification par immatriculation

L'architecture V1 conserve le secret fournisseur côté serveur et permet une saisie manuelle.

Pour activer la récupération automatique réelle, le secret fournisseur doit être présent dans Supabase sous le nom `API_PLAQUE_IMMATRICULATION_TOKEN`, prévu par l'Edge Function. Le secret ne doit jamais être ajouté au code Flutter.

## 5. Android

Au 10 août 2026 :
- les nouvelles applications Google Play doivent actuellement cibler au moins Android 15 / API 35 ;
- à partir du 31 août 2026, les nouvelles applications et mises à jour devront cibler Android 16 / API 36 ou plus.

Pour éviter une mise à niveau immédiate, AutoClair doit viser API 36 avant la publication commerciale si celle-ci intervient à partir du 31 août 2026.

Le Lot 12 vérifie la configuration lorsqu'elle est explicitement lisible, mais une valeur gérée dynamiquement par Flutter doit être reconfirmée au moment de la soumission.

Source vérifiée le 10 août 2026 : documentation officielle Android Developers / Google Play.

## 6. iOS

Depuis le 28 avril 2026, Apple indique que les apps iOS/iPadOS envoyées à App Store Connect doivent être construites avec le SDK iOS 26 ou ultérieur.

La compilation iOS ne peut pas être qualifiée depuis Windows. Elle doit être réalisée sur Mac avec Xcode conforme, puis testée sur appareil réel et/ou TestFlight.

Source vérifiée le 10 août 2026 : documentation officielle Apple Developer.

## 7. Confidentialité

Avant publication :
- confirmer la minimisation des données ;
- confirmer la suppression de compte et des données ;
- confirmer les durées de conservation ;
- publier une politique de confidentialité ;
- renseigner les formulaires de collecte de données dans Google Play et App Store Connect ;
- vérifier les informations transmises aux fournisseurs IA/API ;
- ne jamais exposer une clé privée dans l'application.

## 8. Test final avant ouverture au public

Sur une version signée de production :
1. créer un compte neuf ;
2. ajouter un véhicule manuellement ;
3. tester l'identification par immatriculation si le fournisseur est activé ;
4. ajouter un événement et un document ;
5. analyser un document ;
6. vérifier la création/liaison avec le carnet ;
7. tester une recherche autour de moi ;
8. tester contrôle technique, carburant et recharge selon le véhicule ;
9. tester l'assistant véhicule ;
10. tester les rappels essentiels ;
11. tester l'essai gratuit Bilan 360 ;
12. tester achat, restauration et expiration une fois le paiement branché ;
13. tester hors connexion et refus de géolocalisation ;
14. supprimer le compte ;
15. vérifier qu'aucune donnée technique brute ou secret n'est affiché.

## 9. Règle de décision

`GO CODE V1` signifie que le code et les validations automatisées prévues par les lots sont réussis.

`GO PUBLICATION` ne peut être prononcé qu'après fermeture de tous les bloqueurs externes et exécution des tests de production réels.

AutoClair ne doit jamais présenter l'absence d'un fournisseur, d'un compte store, d'une signature ou d'un paiement comme une fonctionnalité terminée.
