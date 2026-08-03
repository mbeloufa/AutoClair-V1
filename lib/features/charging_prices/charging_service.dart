import 'package:supabase_flutter/supabase_flutter.dart';

import 'charging_station_offer.dart';

class ChargingServiceException implements Exception {
  const ChargingServiceException(this.message);

  final String message;
}

class ChargingService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<ChargingSearchResult> searchStations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String connector,
    required double minimumPowerKw,
    required double energyKwh,
    required String sortBy,
    int resultLimit = 50,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'search-charging-stations',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          'connector': connector,
          'minimum_power_kw': minimumPowerKw,
          'energy_kwh': energyKwh,
          'sort_by': sortBy,
          'result_limit': resultLimit,
        },
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map) {
        throw const ChargingServiceException(
          "Le serveur n'a pas renvoyé une réponse exploitable.",
        );
      }

      final payload = Map<String, dynamic>.from(data);
      if (payload['success'] != true) {
        final message = payload['message']?.toString().trim();
        throw ChargingServiceException(
          message == null || message.isEmpty
              ? 'La recherche des bornes a échoué.'
              : message,
        );
      }

      final rawResults = payload['results'];
      if (rawResults is! List) {
        throw const ChargingServiceException(
          "Le serveur n'a pas renvoyé une liste de bornes.",
        );
      }

      return ChargingSearchResult(
        offers: rawResults
            .map(
              (row) => ChargingStationOffer.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(growable: false),
        cacheHit: payload['cache_hit'] == true,
        sourceFetchedAt: DateTime.tryParse(
          payload['source_fetched_at']?.toString() ?? '',
        ),
        truncated: payload['truncated'] == true,
        energyKwh: _double(payload['energy_kwh']) ?? energyKwh,
        pricingDisclaimer:
            payload['pricing_disclaimer']?.toString().trim() ??
            'Le tarif publié par l’opérateur reste la référence.',
        sourceName:
            payload['source_name']?.toString().trim() ?? 'Base nationale IRVE',
      );
    } on ChargingServiceException {
      rethrow;
    } catch (error) {
      throw ChargingServiceException(_message(error));
    }
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }

  static String _message(Object error) {
    final normalized = error.toString().toLowerCase();

    if (normalized.contains('search-charging-stations') ||
        normalized.contains('function not found') ||
        normalized.contains('404')) {
      return 'Le moteur de comparaison des recharges est indisponible. Vérifiez la fonction Supabase.';
    }
    if (normalized.contains('401') ||
        normalized.contains('unauthorized') ||
        normalized.contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('connection')) {
      return 'Connexion impossible. Vérifiez votre accès Internet.';
    }

    return 'Impossible de récupérer les bornes de recharge.';
  }
}
