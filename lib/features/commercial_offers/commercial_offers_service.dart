import 'package:supabase_flutter/supabase_flutter.dart';

import 'commercial_offer_models.dart';

class CommercialOffersException implements Exception {
  const CommercialOffersException(this.message);
  final String message;
}

class CommercialOffersService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<CommercialOfferBundle> fetchVehicleOffers(
    String vehicleId, {
    int limit = 120,
  }) async {
    try {
      final raw = await _client.rpc(
        'get_vehicle_commercial_offers',
        params: {
          'p_vehicle_id': vehicleId,
          'p_limit': limit.clamp(1, 150).toInt(),
        },
      );

      if (raw is! Map) {
        throw const CommercialOffersException(
          "Le serveur n'a pas renvoyé les offres du véhicule.",
        );
      }

      return CommercialOfferBundle.fromMap(Map<String, dynamic>.from(raw));
    } on CommercialOffersException {
      rethrow;
    } on PostgrestException catch (error) {
      throw CommercialOffersException(_databaseMessage(error));
    } catch (_) {
      throw const CommercialOffersException(
        'Les offres officielles sont temporairement indisponibles.',
      );
    }
  }

  Future<void> saveOffer({
    required String vehicleId,
    required String offerId,
  }) async {
    await _setPreference(
      vehicleId: vehicleId,
      offerId: offerId,
      status: 'SAVED',
    );
  }

  Future<void> unsaveOffer({
    required String vehicleId,
    required String offerId,
  }) async {
    await _setPreference(
      vehicleId: vehicleId,
      offerId: offerId,
      status: 'NONE',
    );
  }

  Future<void> dismissOffer({
    required String vehicleId,
    required String offerId,
  }) async {
    await _setPreference(
      vehicleId: vehicleId,
      offerId: offerId,
      status: 'DISMISSED',
    );
  }

  Future<void> resetDismissedOffers(String vehicleId) async {
    try {
      await _client.rpc(
        'reset_vehicle_offer_dismissals',
        params: {'p_vehicle_id': vehicleId},
      );
    } on PostgrestException catch (error) {
      throw CommercialOffersException(_databaseMessage(error));
    } catch (_) {
      throw const CommercialOffersException(
        'Les offres masquées n’ont pas pu être réinitialisées.',
      );
    }
  }

  Future<void> _setPreference({
    required String vehicleId,
    required String offerId,
    required String status,
  }) async {
    try {
      await _client.rpc(
        'set_vehicle_commercial_offer_preference',
        params: {
          'p_vehicle_id': vehicleId,
          'p_offer_id': offerId,
          'p_status': status,
        },
      );
    } on PostgrestException catch (error) {
      throw CommercialOffersException(_databaseMessage(error));
    } catch (_) {
      throw const CommercialOffersException(
        'Votre choix n’a pas pu être enregistré.',
      );
    }
  }

  static String _databaseMessage(PostgrestException error) {
    final raw = error.message;

    if (raw.contains('COMMERCIAL_OFFERS_AUTH_REQUIRED')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND')) {
      return "Ce véhicule n'existe plus ou ne vous appartient pas.";
    }
    if (raw.contains('COMMERCIAL_OFFERS_OFFER_NOT_FOUND')) {
      return "Cette offre n'est plus disponible.";
    }
    if (raw.contains('COMMERCIAL_OFFERS_STATUS_INVALID')) {
      return 'Le statut demandé est invalide.';
    }
    if (raw.toLowerCase().contains('get_vehicle_commercial_offers')) {
      return 'Le module Offres utiles doit être installé sur Supabase.';
    }

    return 'Les offres du véhicule n’ont pas pu être chargées.';
  }
}
