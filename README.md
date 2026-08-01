# AutoClair — socle Flutter codé

Ce paquet remplace la maquette FlutterFlow comme source principale de l'application.

## Fonctionnalités déjà codées

- onboarding en trois écrans ;
- mémorisation locale de la fin de l'onboarding ;
- création de compte Supabase ;
- connexion e-mail/mot de passe ;
- maintien automatique de la session ;
- protection des routes privées ;
- envoi de l'e-mail de réinitialisation du mot de passe ;
- déconnexion ;
- navigation Accueil / Véhicules / Historique / Compte ;
- messages d'erreur en français ;
- thème visuel AutoClair ;
- aucune clé secrète dans le code.

## Prérequis

- Flutter installé et disponible dans le `PATH` ;
- le projet Supabase `autoclair-dev` ;
- la table `public.users` et son trigger déjà créés ;
- le fournisseur Email activé dans Supabase.

## Installation automatique

Ouvrir PowerShell dans ce dossier puis lancer :

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\bootstrap.ps1
```

Le script :

1. génère les dossiers Android, iOS, Web et Windows ;
2. restaure le code AutoClair ;
3. ajoute l'autorisation Internet Android ;
4. installe les dépendances ;
5. formate le code ;
6. exécute `flutter analyze` et les tests.

## Configuration Supabase

Récupérer dans Supabase, depuis **Connect** ou **Project Settings > API** :

- Project URL ;
- Publishable key.

Il ne faut jamais utiliser `service_role` ou une clé `sb_secret_...`.

Dans PowerShell :

```powershell
$env:AUTOCLAIR_SUPABASE_URL="https://VOTRE-PROJET.supabase.co"
$env:AUTOCLAIR_SUPABASE_PUBLISHABLE_KEY="VOTRE_CLE_PUBLIQUE"
.\run_dev.ps1
```

Pour réinitialiser le mot de passe avec un lien spécifique :

```powershell
$env:AUTOCLAIR_PASSWORD_RESET_REDIRECT="https://votre-url-de-redirection"
```

Cette variable est facultative pour le premier test d'envoi d'e-mail.

## Test critique du module

1. terminer ou passer l'onboarding ;
2. créer un compte avec une adresse unique ;
3. vérifier l'arrivée sur Accueil ;
4. vérifier l'utilisateur dans Supabase Auth ;
5. vérifier la ligne dans `public.users` ;
6. aller dans Compte et se déconnecter ;
7. se reconnecter avec le même compte.

## Commandes utiles

```powershell
flutter analyze
flutter test
flutter run -d chrome
flutter devices
```
