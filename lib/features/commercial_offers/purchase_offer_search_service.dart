import 'package:supabase_flutter/supabase_flutter.dart';

import 'commercial_offer_models.dart';
import 'commercial_offers_service.dart';

class PurchaseOfferSearchCriteria {
  const PurchaseOfferSearchCriteria({
    this.brand,
    this.model,
    this.fuel,
    this.vehicleKind = 'ALL',
  });

  final String? brand;
  final String? model;
  final String? fuel;
  final String vehicleKind;

  bool get isEmpty =>
      (brand == null || brand!.trim().isEmpty) &&
      (model == null || model!.trim().isEmpty) &&
      (fuel == null || fuel!.trim().isEmpty) &&
      vehicleKind == 'ALL';
}

class PurchaseOfferSearchBundle {
  const PurchaseOfferSearchBundle({
    required this.offers,
    required this.availableBrands,
    required this.generatedAt,
    required this.totalCount,
  });

  final List<CommercialOffer> offers;
  final List<String> availableBrands;
  final DateTime generatedAt;
  final int totalCount;

  factory PurchaseOfferSearchBundle.fromMap(Map<String, dynamic> map) {
    final rawOffers = map['offers'];
    final rawBrands = map['available_brands'];

    return PurchaseOfferSearchBundle(
      offers: rawOffers is List
          ? rawOffers
                .whereType<Map>()
                .map(
                  (row) =>
                      CommercialOffer.fromMap(Map<String, dynamic>.from(row)),
                )
                .toList(growable: false)
          : const [],
      availableBrands: rawBrands is List
          ? rawBrands
                .map((value) => value?.toString().trim() ?? '')
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList(growable: false)
          : const [],
      generatedAt:
          DateTime.tryParse(map['generated_at']?.toString() ?? '') ??
          DateTime.now(),
      totalCount: _integer(map['total_count']),
    );
  }
}

class PurchaseOfferSearchService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<PurchaseOfferSearchBundle> search({
    PurchaseOfferSearchCriteria criteria = const PurchaseOfferSearchCriteria(),
    int limit = 100,
  }) async {
    try {
      final raw = await _client.rpc(
        'search_vehicle_purchase_offers_v4',
        params: {
          'p_brand': _nullable(criteria.brand),
          'p_model': _nullable(criteria.model),
          'p_fuel': _nullable(criteria.fuel),
          'p_vehicle_kind': criteria.vehicleKind,
          'p_limit': limit.clamp(1, 150).toInt(),
        },
      );

      if (raw is! Map) {
        throw const CommercialOffersException(
          "Le serveur n'a pas renvoyé les offres de vente.",
        );
      }

      return PurchaseOfferSearchBundle.fromMap(Map<String, dynamic>.from(raw));
    } on CommercialOffersException {
      rethrow;
    } on PostgrestException catch (error) {
      final raw = error.message.toLowerCase();
      if (raw.contains('commercial_offers_auth_required')) {
        throw const CommercialOffersException(
          'Votre session a expiré. Reconnectez-vous.',
        );
      }
      throw const CommercialOffersException(
        "La recherche d'offres de vente est temporairement indisponible.",
      );
    } catch (_) {
      throw const CommercialOffersException(
        "La recherche d'offres de vente est temporairement indisponible.",
      );
    }
  }

  static String? _nullable(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
