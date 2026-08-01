import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AuthErrorMapper {
  static String message(Object error) {
    if (error is AuthException) {
      final value = error.message.toLowerCase();

      if (value.contains('invalid login credentials')) {
        return 'Adresse e-mail ou mot de passe incorrect.';
      }
      if (value.contains('email not confirmed')) {
        return 'Confirmez votre adresse e-mail avant de vous connecter.';
      }
      if (value.contains('user already registered')) {
        return 'Un compte existe déjà avec cette adresse e-mail.';
      }
      if (value.contains('password')) {
        return 'Le mot de passe ne respecte pas les règles de sécurité.';
      }
      if (value.contains('rate limit') || value.contains('too many requests')) {
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      }
    }

    return 'Une erreur est survenue. Vérifiez votre connexion et réessayez.';
  }
}
