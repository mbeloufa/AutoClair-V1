import 'package:supabase_flutter/supabase_flutter.dart';

import 'smart_trip_models.dart';

class SmartTripException implements Exception {
  const SmartTripException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SmartTripService {
  SmartTripService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SmartTripSuggestion>> suggestPlaces({
    required String query,
    SmartTripPoint? around,
  }) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      return const [];
    }

    try {
      final response = await _client.functions.invoke(
        'analyze-smart-trip',
        body: {
          'mode': 'autocomplete',
          'query': normalized,
          if (around != null) 'at': {'lat': around.lat, 'lng': around.lng},
        },
      );
      final raw = response.data;
      if (raw is! Map) {
        return const [];
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['success'] != true) {
        throw SmartTripException(_message(data['error']?.toString()));
      }
      final suggestions = data['suggestions'];
      if (suggestions is! List) {
        return const [];
      }
      return suggestions
          .whereType<Map>()
          .map(
            (item) =>
                SmartTripSuggestion.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.label.isNotEmpty)
          .toList(growable: false);
    } on SmartTripException {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  Future<SmartTripResult> analyze({
    required String vehicleId,
    required Map<String, dynamic> origin,
    required Map<String, dynamic> destination,
    required int maxExtraMinutes,
    double? consumptionPer100,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'analyze-smart-trip',
        body: {
          'mode': 'analyze',
          'vehicle_id': vehicleId,
          'origin': origin,
          'destination': destination,
          'max_extra_minutes': maxExtraMinutes,
          'consumption_per_100': ?consumptionPer100,
        },
      );

      final raw = response.data;
      if (raw is! Map) {
        throw const SmartTripException(
          'Le service trajet a renvoyé une réponse illisible.',
        );
      }

      final data = Map<String, dynamic>.from(raw);
      if (data['success'] != true) {
        throw SmartTripException(_message(data['error']?.toString()));
      }
      return SmartTripResult.fromJson(data);
    } on SmartTripException {
      rethrow;
    } catch (error) {
      final text = error.toString();
      for (final code in const [
        'AUTH_REQUIRED',
        'VEHICLE_NOT_FOUND',
        'INVALID_FINANCIAL_INPUT',
        'PLACE_REQUIRED',
        'PLACE_NOT_FOUND',
        'FUEL_PRICE_UNAVAILABLE',
        'NO_ROUTE',
        'EV_NOT_SUPPORTED_V2',
        'SMART_TRIP_NOT_CONFIGURED',
        'ROUTING_CONFIGURATION_ERROR',
        'ROUTING_TEMPORARILY_BUSY',
        'ROUTING_TIMEOUT',
        'ROUTING_SERVICE_ERROR',
      ]) {
        if (text.contains(code)) {
          throw SmartTripException(_message(code));
        }
      }
      throw const SmartTripException(
        'Le calcul du trajet est momentanément indisponible.',
      );
    }
  }

  static String _message(String? code) {
    return switch (code) {
      'AUTH_REQUIRED' => 'Votre session a expiré. Reconnectez-vous.',
      'VEHICLE_NOT_FOUND' => 'Le véhicule sélectionné n’est plus disponible.',
      'INVALID_FINANCIAL_INPUT' =>
        'Vérifiez la consommation éventuelle et le temps accepté.',
      'PLACE_REQUIRED' || 'PLACE_NOT_FOUND' =>
        'Sélectionnez précisément le départ et la destination proposés.',
      'FUEL_PRICE_UNAVAILABLE' =>
        'Le prix officiel du carburant est momentanément indisponible.',
      'NO_ROUTE' => 'Aucun trajet routier exploitable n’a été trouvé.',
      'EV_NOT_SUPPORTED_V2' =>
        'Le moteur électrique sera proposé avec autonomie et recharge '
            'afin de ne pas afficher un calcul incomplet.',
      'SMART_TRIP_NOT_CONFIGURED' || 'ROUTING_CONFIGURATION_ERROR' =>
        'Le service Trajet intelligent n’est pas encore configuré.',
      'ROUTING_TEMPORARILY_BUSY' || 'ROUTING_TIMEOUT' =>
        'Le calcul routier est très sollicité. Réessayez dans quelques instants.',
      'ROUTING_SERVICE_ERROR' =>
        'Le fournisseur d’itinéraires est momentanément indisponible.',
      _ => 'Le calcul du trajet est momentanément indisponible.',
    };
  }
}
