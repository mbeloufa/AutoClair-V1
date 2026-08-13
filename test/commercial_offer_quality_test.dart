import 'package:autoclair_app/features/commercial_offers/commercial_offer_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchase offer exposes clear badges benefit and conditions', () {
    final offer = CommercialOffer.fromMap({
      'id': 'offer-1',
      'offer_key': 'dacia-bigster',
      'title': 'Offre Dacia Bigster',
      'summary': 'Offre sous conditions.',
      'category': 'NEW_VEHICLE',
      'offer_context': 'VEHICLE_PURCHASE',
      'targeting_scope': 'MODEL',
      'brands': ['Dacia'],
      'model_patterns': ['Bigster'],
      'fuel_types': ['electric'],
      'commercial_value_score': 253,
      'benefit_kind': 'DISCOUNT',
      'benefit_label': 'Avantage client',
      'benefit_value': 520,
      'price_amount': 20520,
      'original_price_amount': 21040,
      'currency': 'EUR',
      'source_name': 'Dacia',
      'official_url': 'https://example.com',
      'conditions_summary': 'Sous réserve de reprise et de financement.',
      'eligibility_notes': '',
      'compatibility': 'COMPATIBLE',
      'relevance_label': 'Modèle correspondant',
      'relevance_score': 100,
      'relevant_now': true,
      'expires_soon': false,
      'is_saved': false,
      'why': const [],
      'requires_manual_eligibility': true,
      'requires_network_participation': false,
      'requires_existing_contract': false,
      'last_verified_at': '2026-08-13T06:00:00Z',
      'auto_extracted': false,
    });

    expect(offer.purchaseBadgeLabels, [
      'Véhicule neuf',
      'Dacia',
      'Bigster',
      'Électrique',
    ]);
    expect(offer.clearBenefitLabel, '520 € de remise');
    expect(
      offer.conditionsPreview,
      'Sous réserve de reprise et de financement.',
    );
    expect(offer.commercialValueScore, 253);
  });
}
