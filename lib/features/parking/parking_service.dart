import 'package:supabase_flutter/supabase_flutter.dart';

import 'parking_offer.dart';

class ParkingServiceException implements Exception {
  const ParkingServiceException(this.message);

  final String message;
}

class ParkingService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<ParkingSearchResult> searchParking({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String parkingType,
    required String sortBy,
    required bool freeOnly,
    required bool accessibleOnly,
    required bool evOnly,
    int resultLimit = 80,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'search-parking',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          'parking_type': parkingType,
          'sort_by': sortBy,
          'free_only': freeOnly,
          'accessible_only': accessibleOnly,
          'ev_only': evOnly,
          'result_limit': resultLimit,
        },
      );

      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map) {
        throw const ParkingServiceException(
          "Le serveur n'a pas renvoyé une réponse exploitable.",
        );
      }

      final payload = Map<String, dynamic>.from(data);
      if (payload['success'] != true) {
        final message = payload['message']?.toString().trim();
        throw ParkingServiceException(
          message == null || message.isEmpty
              ? 'La recherche des parkings a échoué.'
              : message,
        );
      }

      final rawResults = payload['results'];
      if (rawResults is! List) {
        throw const ParkingServiceException(
          "Le serveur n'a pas renvoyé une liste de parkings.",
        );
      }

      return ParkingSearchResult(
        offers: rawResults
            .map(
              (row) =>
                  ParkingOffer.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList(growable: false),
        cacheHit: payload['cache_hit'] == true,
        sourceFetchedAt: DateTime.tryParse(
          payload['source_fetched_at']?.toString() ?? '',
        ),
        sourceName:
            payload['source_name']?.toString().trim() ??
            'OpenStreetMap via Overpass',
        availabilityDisclaimer:
            payload['availability_disclaimer']?.toString().trim() ??
            'La disponibilité en temps réel n’est pas fournie.',
        truncated: payload['truncated'] == true,
        osmBase: DateTime.tryParse(payload['osm_base']?.toString() ?? ''),
      );
    } on ParkingServiceException {
      rethrow;
    } catch (error) {
      throw ParkingServiceException(_message(error));
    }
  }

  static String _message(Object error) {
    final normalized = error.toString().toLowerCase();

    if (normalized.contains('search-parking') ||
        normalized.contains('function not found') ||
        normalized.contains('404')) {
      return 'Le moteur de recherche des parkings est indisponible. Vérifiez la fonction Supabase.';
    }
    if (normalized.contains('401') ||
        normalized.contains('unauthorized') ||
        normalized.contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (normalized.contains('overpass') ||
        normalized.contains('source_unavailable') ||
        normalized.contains('503')) {
      return 'La source cartographique est momentanément indisponible. Réessayez dans quelques instants.';
    }
    if (normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('connection')) {
      return 'Connexion impossible. Vérifiez votre accès Internet.';
    }

    return 'Impossible de récupérer les parkings proches.';
  }
}
