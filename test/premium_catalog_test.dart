import 'package:flutter_test/flutter_test.dart';
import 'package:autoclair_app/features/premium/premium_catalog.dart';

void main() {
  test('V1: annual only, no unjustified unlimited promise', () {
    expect(PremiumCatalog.entitlementId, 'premium');
    expect(PremiumCatalog.annualPriceCentsTtc, 2999);
    expect(PremiumCatalog.annualLabel, 'Annuel');
    expect(PremiumCatalog.freeBenefits, contains('1 premier Bilan AutoClair 360 offert'));
    expect(PremiumCatalog.premiumBenefits.join(' '), isNot(contains('sans crédit')));
    expect(PremiumCatalog.checkoutEnabled, isFalse);
  });

  test('packs are distinct from subscription and never invented', () {
    expect(PremiumCatalog.packs.length, 3);
    expect(PremiumCatalog.packs.map((p) => p.code).toSet().length, 3);
    for (final pack in PremiumCatalog.packs) {
      expect(pack.type, isNot(CommercialProductType.subscription));
      expect(pack.priceCentsTtc, isNull);
      expect(pack.storeProductId, isNull);
      expect(pack.fullySpecified, isFalse);
    }
    expect(PremiumCatalog.packs.last.quantity, 1);
  });

  test('every costly exposed service is flagged for server metering', () {
    expect(PremiumCatalog.featureRights.length, greaterThanOrEqualTo(13));
    for (final f in PremiumCatalog.featureRights) {
      expect(f.free, isNotEmpty);
      expect(f.subscription, isNotEmpty);
      expect(f.singlePurchase, isNotEmpty);
    }
    expect(PremiumCatalog.featureRights
        .where((f) => f.code == 'saved_results')
        .single.requiresServerMetering, isFalse);
  });
}
