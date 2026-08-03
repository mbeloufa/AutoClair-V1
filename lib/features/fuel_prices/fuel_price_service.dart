import 'package:supabase_flutter/supabase_flutter.dart';

import 'fuel_station_offer.dart';

class FuelPriceServiceException implements Exception {
  const FuelPriceServiceException(this.message);

  final String message;
}

class FuelPriceService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<FuelSearchResult> searchStations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String fuelType,
    required String sortBy,
    int resultLimit = 50,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'search-fuel-stations',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          'fuel_type': fuelType,
          'sort_by': sortBy,
          'result_limit': resultLimit,
        },
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map) {
        throw const FuelPriceServiceException(
          "Le serveur n'a pas renvoyé une réponse exploitable.",
        );
      }

      final payload = Map<String, dynamic>.from(data);
      if (payload['success'] != true) {
        final message = payload['message']?.toString().trim();
        throw FuelPriceServiceException(
          message == null || message.isEmpty
              ? 'La recherche des stations a échoué.'
              : message,
        );
      }

      final rawResults = payload['results'];
      if (rawResults is! List) {
        throw const FuelPriceServiceException(
          "Le serveur n'a pas renvoyé une liste de stations.",
        );
      }

      final sourceFetchedAt = DateTime.tryParse(
        payload['source_fetched_at']?.toString() ?? '',
      );

      return FuelSearchResult(
        offers: rawResults
            .map(
              (row) => FuelStationOffer.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(growable: false),
        cacheHit: payload['cache_hit'] == true,
        sourceFetchedAt: sourceFetchedAt,
        truncated: payload['truncated'] == true,
      );
    } on FuelPriceServiceException {
      rethrow;
    } catch (error) {
      throw FuelPriceServiceException(_message(error));
    }
  }

  static String _message(Object error) {
    final normalized = error.toString().toLowerCase();

    if (normalized.contains('search-fuel-stations') ||
        normalized.contains('function not found') ||
        normalized.contains('404')) {
      return 'Le moteur de comparaison des carburants est indisponible. Vérifiez la fonction Supabase.';
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

    return 'Impossible de récupérer les prix des carburants.';
  }
}
