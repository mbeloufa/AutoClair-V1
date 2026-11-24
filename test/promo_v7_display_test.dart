import 'package:flutter_test/flutter_test.dart';
import '../lib/features/commercial_offers/commercial_offer_models.dart';

void main() {
  test('V7 preserves fitting scope instead of general tyre discount', () {
    final offer = CommercialOffer.fromMap({
      'id': 'fixture', 'offer_key': 'promo-v7:fixture', 'category': 'TYRES',
      'benefit_kind': 'PERCENT', 'benefit_value': 50,
      'benefit_label': '50% du montage offert',
    });
    expect(offer.clearBenefitLabel, '50% du montage offert');
    expect(offer.priceLabel, '50% du montage offert');
  });
  test('V7 preserves maximum and unit', () {
    final offer = CommercialOffer.fromMap({
      'offer_key': 'promo-v7:fixture', 'benefit_kind': 'REIMBURSEMENT',
      'benefit_value': 120, 'benefit_label': 'Jusqu’à 120 € remboursés pour 4 pneus',
    });
    expect(offer.clearBenefitLabel, 'Jusqu’à 120 € remboursés pour 4 pneus');
  });
  test('Legacy formatting stays unchanged', () {
    final offer = CommercialOffer.fromMap({
      'offer_key': 'legacy-fixture', 'benefit_kind': 'PERCENT', 'benefit_value': 10,
      'benefit_label': '-10 %',
    });
    expect(offer.clearBenefitLabel, '10 % de remise');
  });
}
