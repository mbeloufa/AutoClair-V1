import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test(
    'commercial Lot 1 prepares store verified Premium without fake prices',
    () {
      final pubspec = source('pubspec.yaml');
      final router = source('lib/core/router/app_router.dart');
      final premiumService = source(
        'lib/features/premium/premium_service.dart',
      );
      final premiumPage = source('lib/features/premium/premium_page.dart');
      final vehicle360Page = source(
        'lib/features/vehicle_insights/vehicle_360_page.dart',
      );
      final vehicle360Service = source(
        'lib/features/vehicle_insights/vehicle_360_service.dart',
      );
      final edge = source(
        'supabase/functions/sync-premium-entitlement/index.ts',
      );
      final config = source('supabase/config.toml');

      expect(pubspec, contains('purchases_flutter: 10.8.0'));
      expect(router, contains("path: '/premium'"));

      expect(premiumService, contains('REVENUECAT_IOS_PUBLIC_KEY'));
      expect(premiumService, contains('REVENUECAT_ANDROID_PUBLIC_KEY'));
      expect(premiumService, isNot(contains('REVENUECAT_SECRET_API_KEY')));
      expect(premiumService, contains('Purchases.purchase('));
      expect(premiumService, contains('PurchaseParams.package(offer.package)'));
      expect(premiumService, isNot(contains('Purchases.purchasePackage')));
      expect(premiumService, contains('Purchases.restorePurchases'));
      expect(premiumService, contains('storeProduct.priceString'));
      expect(premiumService, contains("entitlements.active.containsKey"));

      expect(RegExp(r'\b\d+[,.]\d{2}\s*€').hasMatch(premiumPage), isFalse);
      expect(premiumPage, contains('Le prix affiché est celui de votre store'));

      expect(vehicle360Page, contains("'/premium'"));
      expect(vehicle360Page, isNot(contains('stores de production')));
      expect(vehicle360Service, contains('sync-premium-entitlement'));

      expect(edge, contains('REVENUECAT_SECRET_API_KEY'));
      expect(edge, contains('/v1/subscribers/'));
      expect(edge, contains('upsert_vehicle_360_entitlement'));
      expect(edge, contains('encodeURIComponent(user.id)'));

      expect(config, contains('[functions.sync-premium-entitlement]'));
      expect(config, contains('verify_jwt = true'));
    },
  );
}
