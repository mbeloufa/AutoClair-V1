import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_deletion_confirmation.dart';

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;
}

class AccountDeletionService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> deleteCurrentAccount({
    required String email,
    required String confirmation,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken;

    if (accessToken == null || accessToken.isEmpty) {
      throw const AccountDeletionException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }

    try {
      final response = await _client.functions.invoke(
        'delete-account',
        body: {'email': email.trim(), 'confirmation': confirmation.trim()},
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      final data = response.data;

      if (data is! Map) {
        throw const AccountDeletionException(
          'Le serveur a renvoyé une réponse invalide.',
        );
      }

      final payload = Map<String, dynamic>.from(data);

      if (payload['success'] != true) {
        throw AccountDeletionException(
          payload['message']?.toString() ??
              "Le compte n'a pas pu être supprimé.",
        );
      }

      await _client.auth.signOut(scope: SignOutScope.local);
    } on FunctionException catch (error) {
      throw AccountDeletionException(_functionMessage(error));
    } on AccountDeletionException {
      rethrow;
    } on AuthException {
      throw const AccountDeletionException(
        'Le compte a été supprimé, mais la session locale '
        "n'a pas pu être fermée correctement. Fermez puis "
        "rouvrez l'application.",
      );
    } catch (_) {
      throw const AccountDeletionException(
        'La suppression du compte est temporairement indisponible.',
      );
    }
  }

  static String _functionMessage(FunctionException error) {
    final details = error.details;

    if (details is Map) {
      final payload = Map<String, dynamic>.from(details);
      final message = payload['message']?.toString().trim();

      if (message != null && message.isNotEmpty) {
        return message;
      }

      return _errorCodeMessage(payload['error_code']?.toString());
    }

    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }

    return switch (error.status) {
      400 => 'Les informations de confirmation sont invalides.',
      401 => 'Votre session a expiré. Reconnectez-vous.',
      409 => 'Le compte ne peut pas être supprimé pendant une analyse.',
      413 =>
        'Le compte contient trop de fichiers pour être supprimé '
            'en une seule opération.',
      _ => "Le compte n'a pas pu être supprimé.",
    };
  }

  static String _errorCodeMessage(String? errorCode) {
    return switch (errorCode) {
      'ACCOUNT_CONFIRMATION_INVALID' =>
        'Saisissez exactement '
            '« ${AccountDeletionConfirmation.requiredPhrase} ».',
      'ACCOUNT_EMAIL_CONFIRMATION_INVALID' =>
        "L'adresse e-mail ne correspond pas au compte connecté.",
      'ACCOUNT_ANALYSIS_PROCESSING' =>
        'Le compte ne peut pas être supprimé pendant une analyse.',
      'ACCOUNT_STORAGE_LIST_FAILED' || 'ACCOUNT_STORAGE_DELETE_FAILED' =>
        "Les fichiers privés du compte n'ont pas tous pu être supprimés.",
      'ACCOUNT_AUTH_DELETE_FAILED' =>
        "Le compte utilisateur n'a pas pu être supprimé. Réessayez.",
      'SERVER_CONFIGURATION_ERROR' =>
        'La configuration serveur doit être vérifiée.',
      _ => "Le compte n'a pas pu être supprimé.",
    };
  }
}
