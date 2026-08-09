import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_identification_result.dart';
import 'vehicle_registration.dart';

class VehicleIdentificationException implements Exception {
  const VehicleIdentificationException(this.message, {this.errorCode});

  final String message;
  final String? errorCode;
}

class VehicleIdentificationService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<VehicleIdentificationResult> identify(String registration) async {
    final validation = VehicleRegistration.lookupValidationMessage(
      registration,
    );
    if (validation != null) {
      throw VehicleIdentificationException(
        validation,
        errorCode: 'VEHICLE_REGISTRATION_INVALID',
      );
    }

    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken;

    if (accessToken == null || accessToken.isEmpty) {
      throw const VehicleIdentificationException(
        'Votre session a expiré. Reconnectez-vous.',
        errorCode: 'AUTH_REQUIRED',
      );
    }

    try {
      final response = await _client.functions.invoke(
        'identify-vehicle',
        body: {'registration': VehicleRegistration.format(registration)},
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      final data = response.data;
      if (data is! Map) {
        throw const VehicleIdentificationException(
          "Le service d'identification a renvoyé une réponse invalide.",
        );
      }

      final payload = Map<String, dynamic>.from(data);

      if (payload['success'] != true) {
        throw VehicleIdentificationException(
          payload['message']?.toString() ??
              "Le véhicule n'a pas pu être identifié.",
          errorCode: payload['error_code']?.toString(),
        );
      }

      final rawVehicle = payload['vehicle'];
      if (rawVehicle is! Map) {
        throw const VehicleIdentificationException(
          "Le véhicule identifié est incomplet.",
        );
      }

      return VehicleIdentificationResult.fromMap(
        Map<String, dynamic>.from(rawVehicle),
      );
    } on FunctionException catch (error) {
      throw VehicleIdentificationException(
        _functionMessage(error),
        errorCode: _functionErrorCode(error),
      );
    } on VehicleIdentificationException {
      rethrow;
    } on FormatException {
      throw const VehicleIdentificationException(
        "Le véhicule identifié est incomplet. Complétez les informations manuellement.",
      );
    } catch (_) {
      throw const VehicleIdentificationException(
        "L'identification automatique est temporairement indisponible. "
        'Vous pouvez continuer manuellement.',
      );
    }
  }

  static String _functionMessage(FunctionException error) {
    final details = error.details;

    if (details is Map) {
      final payload = Map<String, dynamic>.from(details);
      final message = payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }

    return switch (error.status) {
      400 => "L'immatriculation n'est pas reconnue.",
      401 => 'Votre session a expiré. Reconnectez-vous.',
      404 =>
        "Aucun véhicule n'a été trouvé pour cette immatriculation. "
            'Complétez les informations manuellement.',
      429 =>
        "Le service d'identification reçoit trop de demandes. "
            'Réessayez dans quelques instants.',
      503 =>
        "L'identification automatique n'est pas encore activée. "
            'Vous pouvez continuer manuellement.',
      _ =>
        "L'identification automatique est temporairement indisponible. "
            'Vous pouvez continuer manuellement.',
    };
  }

  static String? _functionErrorCode(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      return details['error_code']?.toString();
    }
    return null;
  }
}
