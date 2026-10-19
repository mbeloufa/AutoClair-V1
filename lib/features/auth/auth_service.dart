import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_env.dart';
import '../vehicle_care/vehicle_event_notification_service.dart';
import '../../core/utils/auth_error_mapper.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;
}

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim(), 'locale': 'fr-FR'},
      );
    } catch (error) {
      throw AuthServiceException(AuthErrorMapper.message(error));
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw AuthServiceException(AuthErrorMapper.message(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppEnv.passwordResetRedirect.trim().isEmpty
            ? 'autoclair://auth/reset'
            : AppEnv.passwordResetRedirect.trim(),
      );
    } catch (error) {
      throw AuthServiceException(AuthErrorMapper.message(error));
    }
  }

  Future<void> updatePassword(String password) async {
    if (_client.auth.currentSession == null) {
      throw const AuthServiceException(
        'Le lien de récupération est expiré. Demandez un nouveau lien.',
      );
    }
    if (password.length < 12) {
      throw const AuthServiceException(
        'Utilisez un mot de passe de 12 caractères minimum.',
      );
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } catch (error) {
      throw AuthServiceException(AuthErrorMapper.message(error));
    }
  }

  Future<void> logout() async {
    try {
      await VehicleEventNotificationService.instance.clearForAccountSwitch();
      await _client.auth.signOut();
    } catch (error) {
      throw AuthServiceException(AuthErrorMapper.message(error));
    }
  }
}
