import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'vehicle_360_models.dart';

class Vehicle360Exception implements Exception {
  const Vehicle360Exception(this.message, {this.code});

  final String message;
  final String? code;
}

class Vehicle360Service {
  SupabaseClient get _client => Supabase.instance.client;

  static const _uuid = Uuid();

  Future<Vehicle360Precheck> precheck(String vehicleId) async {
    final payload = await _invokeReport({
      'action': 'precheck',
      'vehicle_id': vehicleId,
    });
    return Vehicle360Precheck.fromMap(payload);
  }

  Future<Vehicle360Report> generate(
    String vehicleId, {
    bool forceRefresh = false,
  }) async {
    final payload = await _invokeReport({
      'action': 'generate',
      'vehicle_id': vehicleId,
      'request_key': _uuid.v4(),
      'force_refresh': forceRefresh,
    });

    final report = Vehicle360Report.tryFromEnvelope(payload['data']);
    if (report == null) {
      throw const Vehicle360Exception(
        "Le bilan a été généré mais sa réponse est incomplète.",
        code: 'INVALID_REPORT_RESPONSE',
      );
    }
    return report;
  }

  Future<Vehicle360Report?> latest(String vehicleId) async {
    final payload = await _invokeReport({
      'action': 'latest',
      'vehicle_id': vehicleId,
    });
    return Vehicle360Report.tryFromEnvelope(payload['data']);
  }

  Future<void> refreshValuation(
    String vehicleId, {
    bool forceRefresh = false,
  }) async {
    final token = _requireAccessToken();
    try {
      final response = await _client.functions.invoke(
        'refresh-vehicle-valuation',
        body: {'vehicle_id': vehicleId, 'force_refresh': forceRefresh},
        headers: {'Authorization': 'Bearer $token'},
      );
      final payload = _payload(response.data);
      if (payload['success'] != true) {
        throw Vehicle360Exception(
          _messageFromPayload(payload),
          code: payload['error']?.toString(),
        );
      }
    } on FunctionException catch (error) {
      throw Vehicle360Exception(
        _functionMessage(error),
        code: _functionCode(error),
      );
    } on Vehicle360Exception {
      rethrow;
    } catch (_) {
      throw const Vehicle360Exception(
        "La cote du véhicule n'a pas pu être actualisée.",
        code: 'VALUATION_REFRESH_FAILED',
      );
    }
  }

  Future<Map<String, dynamic>> _invokeReport(Map<String, dynamic> body) async {
    final token = _requireAccessToken();
    try {
      final response = await _client.functions.invoke(
        'generate-vehicle-360-report',
        body: body,
        headers: {'Authorization': 'Bearer $token'},
      );
      final payload = _payload(response.data);
      if (payload['success'] != true) {
        throw Vehicle360Exception(
          _messageFromPayload(payload),
          code: payload['error']?.toString(),
        );
      }
      return payload;
    } on FunctionException catch (error) {
      throw Vehicle360Exception(
        _functionMessage(error),
        code: _functionCode(error),
      );
    } on Vehicle360Exception {
      rethrow;
    } catch (_) {
      throw const Vehicle360Exception(
        'Le service de bilan est temporairement indisponible.',
        code: 'REPORT_SERVICE_UNAVAILABLE',
      );
    }
  }

  String _requireAccessToken() {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const Vehicle360Exception(
        'Votre session a expiré. Reconnectez-vous.',
        code: 'AUTHENTICATION_REQUIRED',
      );
    }
    return token;
  }

  static Map<String, dynamic> _payload(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const Vehicle360Exception(
      'Le serveur a renvoyé une réponse invalide.',
      code: 'INVALID_SERVER_RESPONSE',
    );
  }

  static String _functionCode(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final payload = Map<String, dynamic>.from(details);
      return payload['error']?.toString() ??
          payload['error_code']?.toString() ??
          'FUNCTION_ERROR';
    }
    return 'FUNCTION_ERROR';
  }

  static String _functionMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final payload = Map<String, dynamic>.from(details);
      return _messageFromPayload(payload);
    }
    if (details is String && details.trim().isNotEmpty) {
      return _friendlyMessage(details.trim());
    }
    return switch (error.status) {
      401 => 'Votre session a expiré. Reconnectez-vous.',
      402 => 'Un accès Premium ou un crédit de bilan est nécessaire.',
      404 => "Ce véhicule n'existe plus ou ne vous appartient pas.",
      409 => "La cote de marché n'est pas encore configurée.",
      422 => 'Complétez les informations essentielles du véhicule.',
      429 => 'Le service est momentanément très sollicité.',
      504 =>
        'Le bilan prend plus de temps que prévu. Réessayez dans un instant.',
      _ => 'Le bilan AutoClair n’a pas pu être généré.',
    };
  }

  static String _messageFromPayload(Map<String, dynamic> payload) {
    final code =
        payload['error']?.toString() ?? payload['error_code']?.toString();
    final message = payload['message']?.toString().trim();
    return _friendlyMessage(code ?? message ?? 'UNKNOWN_ERROR');
  }

  static String _friendlyMessage(String raw) {
    if (raw.contains('INSUFFICIENT_VEHICLE_DATA')) {
      return 'Complétez au minimum la marque, le modèle et le kilométrage.';
    }
    if (raw.contains('PAYWALL_REQUIRED') || raw.contains('NO_REPORT_CREDIT')) {
      return 'Un accès Premium ou un crédit de bilan est nécessaire.';
    }
    if (raw.contains('VALUATION_PROVIDER_NOT_CONFIGURED')) {
      return 'La cote de marché sera disponible après le branchement du fournisseur professionnel.';
    }
    if (raw.contains('VALUATION_NOT_AVAILABLE')) {
      return "Aucune cote fiable n'est disponible pour ce véhicule.";
    }
    if (raw.contains('OPENAI_API_KEY_MISSING') ||
        raw.contains('OPENAI_MODEL_MISSING')) {
      return 'La configuration du moteur d’analyse doit être vérifiée.';
    }
    if (raw.contains('AUTHENTICATION_REQUIRED') ||
        raw.contains('INVALID_OR_EXPIRED_TOKEN')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('VEHICLE_NOT_FOUND_OR_FORBIDDEN')) {
      return "Ce véhicule n'existe plus ou ne vous appartient pas.";
    }
    if (raw.contains('OPENAI_HTTP_429')) {
      return 'Le moteur d’analyse est momentanément très sollicité.';
    }
    if (raw.contains('OPENAI_HTTP_')) {
      return 'Le moteur d’analyse est temporairement indisponible.';
    }
    if (raw == 'UNKNOWN_ERROR' || raw.startsWith('FUNCTION_ERROR')) {
      return 'Le bilan AutoClair n’a pas pu être généré.';
    }
    return raw;
  }
}
