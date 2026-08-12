import 'package:flutter_test/flutter_test.dart';

import 'package:autoclair_app/features/premium/premium_catalog.dart';

void main() {
  test('commercial V1 keeps a simple free and premium model', () {
    expect(PremiumCatalog.entitlementId, 'premium');
    expect(PremiumCatalog.freeTitle, 'AutoClair Gratuit');
    expect(PremiumCatalog.premiumTitle, 'AutoClair Premium');

    expect(
      PremiumCatalog.freeBenefits,
      contains('1 premier Bilan AutoClair 360 offert'),
    );
    expect(
      PremiumCatalog.premiumBenefits,
      contains('Bilans AutoClair 360 sans crédit'),
    );
  });
}
