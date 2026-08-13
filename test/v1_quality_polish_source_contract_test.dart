import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('V1 quality polish keeps core journeys simple and explicit', () {
    final nearby = source('lib/features/home/nearby_location_picker_card.dart');
    final charging = source(
      'lib/features/charging_prices/charging_compare_page.dart',
    );
    final parking = source('lib/features/parking/parking_page.dart');
    final models = source(
      'lib/features/commercial_offers/commercial_offer_models.dart',
    );
    final purchase = source(
      'lib/features/commercial_offers/purchase_offer_search_page.dart',
    );
    final offers = source(
      'lib/features/commercial_offers/commercial_offers_page.dart',
    );
    final maintenance = source(
      'lib/features/vehicle_care/vehicle_care_page.dart',
    );
    final presentation = source(
      'lib/features/vehicle_care/vehicle_maintenance_presentation.dart',
    );
    final migration = source(
      'supabase/migrations/20260813100000_purchase_offer_quality_ranking_v1.sql',
    );

    expect(nearby, contains('Autour de moi'));
    expect(nearby, contains('Choisir un lieu'));
    expect(nearby, isNot(contains('Utiliser ma position')));
    expect(nearby, contains('_NearbyLocationSearchSheet'));

    expect(charging, isNot(contains('Quantité à recharger')));
    expect(charging, isNot(contains('ChargingCatalog.energyChoicesKwh')));
    expect(charging, contains('isDevicePosition'));

    expect(parking, contains('Recherche avancée'));
    expect(parking, contains('Horaires, type, rayon et équipements'));
    expect(parking, contains("label: 'Économiser'"));
    expect(parking, contains("title: 'Gratuits uniquement'"));

    expect(models, contains('purchaseBadgeLabels'));
    expect(models, contains('clearBenefitLabel'));
    expect(models, contains('conditionsPreview'));
    expect(purchase, contains('Conditions essentielles'));
    expect(offers, contains('Conditions essentielles'));

    final valueRank = migration.indexOf('e.commercial_value_score desc');
    final featuredRank = migration.indexOf(
      'coalesce(e.is_featured, false) desc',
    );
    expect(valueRank, greaterThanOrEqualTo(0));
    expect(featuredRank, greaterThan(valueRank));
    expect(migration, contains("'brands'"));
    expect(migration, contains("'model_patterns'"));
    expect(migration, contains("'fuel_types'"));

    expect(presentation, contains("'Plan constructeur'"));
    expect(presentation, contains("'Contrôle périodique'"));
    expect(maintenance, contains('Voir l’échéance'));
    expect(maintenance, contains('onOpenMaintenance'));
  });
}
