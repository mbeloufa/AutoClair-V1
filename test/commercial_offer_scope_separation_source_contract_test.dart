import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vehicle and purchase offers use separate routes and RPCs', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final service = File(
      'lib/features/commercial_offers/commercial_offers_service.dart',
    ).readAsStringSync();
    final purchaseService = File(
      'lib/features/commercial_offers/purchase_offer_search_service.dart',
    ).readAsStringSync();
    final vehiclePage = File(
      'lib/features/commercial_offers/commercial_offers_page.dart',
    ).readAsStringSync();
    final home = File('lib/features/home/home_page.dart').readAsStringSync();

    expect(router, contains("path: '/offers'"));
    expect(router, contains('const PurchaseOfferSearchPage()'));
    expect(router, contains("path: '/vehicles/:vehicleId/offers'"));
    expect(router, contains('CommercialOffersPage('));
    expect(service, contains("'get_vehicle_after_sales_offers_v4'"));
    expect(purchaseService, contains("'search_vehicle_purchase_offers_v4'"));
    expect(
      purchaseService,
      contains("import 'commercial_offers_service.dart';"),
      reason:
          'Le service de recherche doit importer CommercialOffersException.',
    );
    expect(purchaseService, contains('on CommercialOffersException'));
    expect(vehiclePage, contains("title: const Text('Offres après-vente')"));
    expect(vehiclePage, contains('Après-vente ·'));
    expect(home, contains("label: \"Offres d'achat\""));
  });

  test('collector classifies purchase offers before publication', () {
    final extractor = File(
      'supabase/functions/sync-commercial-offers-v4/extractor.ts',
    ).readAsStringSync();
    final index = File(
      'supabase/functions/sync-commercial-offers-v4/index.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260807093000_commercial_offer_scope_separation_v1.sql',
    ).readAsStringSync();

    expect(extractor, contains('offerContextFor'));
    expect(extractor, contains("'VEHICLE_PURCHASE'"));
    expect(index, contains('offer_context: offer.offerContext'));
    expect(migration, contains('get_vehicle_after_sales_offers_v4'));
    expect(migration, contains('search_vehicle_purchase_offers_v4'));
    expect(migration, contains('classify_commercial_offer_context_v5'));
  });
}
