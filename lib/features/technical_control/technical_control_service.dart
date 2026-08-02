import 'package:supabase_flutter/supabase_flutter.dart';

import 'technical_control_catalog.dart';
import 'technical_control_offer.dart';

class TechnicalControlServiceException implements Exception {
  const TechnicalControlServiceException(this.message);

  final String message;
}

class TechnicalControlService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<TechnicalControlCatalog> fetchCatalog() async {
    try {
      final vehicleCategories = await _fetchDistinctOptions(
        idColumn: 'vehicle_category_id',
        labelColumn: 'vehicle_category_label',
      );
      final energyCategories = await _fetchDistinctOptions(
        idColumn: 'energy_category_id',
        labelColumn: 'energy_category_label',
      );

      if (vehicleCategories.isEmpty || energyCategories.isEmpty) {
        throw const TechnicalControlServiceException(
          'Les catégories de contrôle technique ne sont pas encore disponibles.',
        );
      }

      return TechnicalControlCatalog(
        vehicleCategories: vehicleCategories,
        energyCategories: energyCategories,
      );
    } on TechnicalControlServiceException {
      rethrow;
    } catch (error) {
      throw TechnicalControlServiceException(_message(error));
    }
  }

  Future<List<TechnicalControlOffer>> searchOffers({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String vehicleCategoryId,
    required String energyCategoryId,
    required String sortBy,
    int resultLimit = 50,
  }) async {
    try {
      final data = await _client.rpc(
        'search_technical_control_prices',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_radius_km': radiusKm,
          'p_vehicle_category_id': vehicleCategoryId,
          'p_energy_category_id': energyCategoryId,
          'p_sort_by': sortBy,
          'p_result_limit': resultLimit,
        },
      );

      if (data is! List) {
        throw const TechnicalControlServiceException(
          "Le serveur n'a pas renvoyé une liste de tarifs.",
        );
      }

      return data
          .map(
            (row) => TechnicalControlOffer.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on TechnicalControlServiceException {
      rethrow;
    } catch (error) {
      throw TechnicalControlServiceException(_message(error));
    }
  }

  Future<List<TechnicalControlCatalogOption>> _fetchDistinctOptions({
    required String idColumn,
    required String labelColumn,
  }) async {
    final options = <TechnicalControlCatalogOption>[];
    String? lastId;

    for (var index = 0; index < 50; index += 1) {
      final List<dynamic> data;

      if (lastId == null) {
        data = await _client
            .from('technical_control_prices')
            .select('$idColumn,$labelColumn')
            .order(idColumn, ascending: true)
            .limit(1);
      } else {
        data = await _client
            .from('technical_control_prices')
            .select('$idColumn,$labelColumn')
            .gt(idColumn, lastId)
            .order(idColumn, ascending: true)
            .limit(1);
      }

      if (data.isEmpty) break;

      final row = Map<String, dynamic>.from(data.first as Map);
      final id = row[idColumn]?.toString().trim();
      final label = row[labelColumn]?.toString().trim();

      if (id == null || id.isEmpty || label == null || label.isEmpty) {
        break;
      }

      options.add(TechnicalControlCatalogOption(id: id, label: label));
      lastId = id;
    }

    options.sort(
      (left, right) =>
          left.label.toLowerCase().compareTo(right.label.toLowerCase()),
    );

    return List.unmodifiable(options);
  }

  static String _message(Object error) {
    final rawMessage = switch (error) {
      PostgrestException() => error.message,
      FormatException() => error.message,
      _ => error.toString(),
    };
    final normalized = rawMessage.toLowerCase();

    if (normalized.contains('search_technical_control_prices')) {
      return 'Le moteur de comparaison est indisponible. Vérifiez la fonction Supabase.';
    }
    if (normalized.contains('permission') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return "Vous n'êtes pas autorisé à consulter ces tarifs.";
    }
    if (normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('connection')) {
      return 'Connexion impossible. Vérifiez votre accès Internet.';
    }

    return 'Impossible de récupérer les prix des contrôles techniques.';
  }
}
