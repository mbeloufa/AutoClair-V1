import 'package:autoclair_app/features/commercial_offers/commercial_offer_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a relevant official offer for the vehicle', () {
    final bundle = CommercialOfferBundle.fromMap({
      'vehicle_id': 'vehicle-1',
      'vehicle_name': 'Ma Golf',
      'generated_at': '2026-08-04T12:00:00Z',
      'last_successful_sync_at': '2026-08-04T04:20:00Z',
      'active_source_count': 4,
      'active_offer_count': 12,
      'offers': [
        {
          'id': 'offer-1',
          'offer_key': 'vw-contract',
          'title': 'Contrat d’entretien Volkswagen',
          'summary': 'Entretien courant pendant 24 mois.',
          'category': 'CONTRACT',
          'benefit_kind': 'INFO',
          'benefit_label': 'Contrat 24 mois',
          'currency': 'EUR',
          'starts_at': '2026-01-01',
          'ends_at': '2026-08-31',
          'source_name': 'Volkswagen France',
          'official_url': 'https://www.volkswagen.fr/offre',
          'conditions_summary': 'Véhicule de moins de 13 ans.',
          'eligibility_notes': 'Sous réserve d’acceptation.',
          'compatibility': 'COMPATIBLE',
          'relevance_label': 'Très pertinente',
          'relevance_score': 88,
          'relevant_now': true,
          'expires_soon': false,
          'is_saved': true,
          'why': [
            'Marque Volkswagen correspondante',
            'Une échéance d’entretien approche',
          ],
          'requires_manual_eligibility': false,
          'requires_network_participation': true,
          'requires_existing_contract': false,
          'last_verified_at': '2026-08-04T04:20:00Z',
        },
      ],
    });

    expect(bundle.vehicleName, 'Ma Golf');
    expect(bundle.offers, hasLength(1));
    expect(bundle.relevantNowCount, 1);
    expect(bundle.savedCount, 1);
    expect(
      bundle.topOffer?.compatibilityLabel,
      'Compatible avec votre véhicule',
    );
    expect(bundle.topOffer?.categoryLabel, 'Contrat d’entretien');
  });

  test('keeps uncertain eligibility explicit', () {
    final offer = CommercialOffer.fromMap({
      'id': 'offer-2',
      'offer_key': 'inspection',
      'title': 'Pack contrôle technique',
      'summary': 'Offre réseau.',
      'category': 'INSPECTION',
      'benefit_kind': 'FIXED_PRICE',
      'benefit_label': 'À partir de 99 €',
      'price_amount': 99,
      'currency': 'EUR',
      'source_name': 'Peugeot France',
      'official_url': 'https://www.peugeot.fr/offre',
      'conditions_summary': 'Hors motorisation électrique et hybride.',
      'eligibility_notes': 'Garage participant à confirmer.',
      'compatibility': 'CHECK',
      'relevance_label': 'À vérifier',
      'relevance_score': 54,
      'relevant_now': false,
      'expires_soon': false,
      'is_saved': false,
      'why': ['Année du véhicule à confirmer'],
      'requires_manual_eligibility': true,
      'requires_network_participation': true,
      'requires_existing_contract': false,
      'last_verified_at': '2026-08-04T04:20:00Z',
    });

    expect(offer.compatibilityLabel, 'Conditions à vérifier');
    expect(offer.priceLabel, '99 EUR');
    expect(offer.relevantNow, isFalse);
  });

  test('calculates savings only from comparable prices', () {
    final offer = CommercialOffer.fromMap({
      'id': 'offer-3',
      'offer_key': 'accessories',
      'title': 'Accessoires',
      'summary': '',
      'category': 'ACCESSORIES',
      'benefit_kind': 'FIXED_PRICE',
      'benefit_label': 'Promotion',
      'price_amount': 120,
      'original_price_amount': 160,
      'currency': 'EUR',
      'source_name': 'Source officielle',
      'official_url': 'https://example.com/offre',
      'conditions_summary': '',
      'eligibility_notes': '',
      'compatibility': 'LIKELY',
      'relevance_label': 'À considérer',
      'relevance_score': 60,
      'relevant_now': false,
      'expires_soon': false,
      'is_saved': false,
      'why': [],
      'requires_manual_eligibility': false,
      'requires_network_participation': true,
      'requires_existing_contract': false,
      'last_verified_at': '2026-08-04T04:20:00Z',
    });

    expect(offer.calculatedSavings, 40);
  });
}
