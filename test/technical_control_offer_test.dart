import 'package:autoclair_app/features/technical_control/technical_control_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TechnicalControlOffer', () {
    test('convertit une ligne RPC complète', () {
      final offer = TechnicalControlOffer.fromJson({
        'center_siret': '12345678901234',
        'denomination': 'CENTRE AUTOCLAIR',
        'address': '1 rue du Test',
        'postal_code': '21000',
        'city': 'Dijon',
        'phone': '0380000000',
        'website': 'https://example.test',
        'latitude': 47.32,
        'longitude': '5.04',
        'distance_km': '4.25',
        'vehicle_category_id': 'VP',
        'vehicle_category_label': 'Véhicule particulier',
        'energy_category_id': 'ES',
        'energy_category_label': 'Essence',
        'inspection_price': '79.90',
        'reinspection_min_price': 10,
        'reinspection_max_price': '25.00',
        'tariff_updated_at': '2026-08-01T10:15:00Z',
      });

      expect(offer.centerSiret, '12345678901234');
      expect(offer.cityLine, '21000 Dijon');
      expect(offer.fullAddress, '1 rue du Test, 21000 Dijon');
      expect(offer.longitude, 5.04);
      expect(offer.distanceKm, 4.25);
      expect(offer.inspectionPrice, 79.9);
      expect(offer.reinspectionMinPrice, 10);
      expect(offer.tariffUpdatedAt, DateTime.utc(2026, 8, 1, 10, 15));
    });

    test('accepte les informations facultatives absentes', () {
      final offer = TechnicalControlOffer.fromJson({
        'center_siret': '12345678901234',
        'denomination': 'CENTRE AUTOCLAIR',
        'distance_km': 12,
        'vehicle_category_id': 'VP',
        'vehicle_category_label': 'Véhicule particulier',
        'energy_category_id': 'GO',
        'energy_category_label': 'Gazole',
        'inspection_price': 82,
      });

      expect(offer.fullAddress, isEmpty);
      expect(offer.phone, isNull);
      expect(offer.website, isNull);
      expect(offer.reinspectionMinPrice, isNull);
    });

    test('rejette un prix obligatoire invalide', () {
      expect(
        () => TechnicalControlOffer.fromJson({
          'center_siret': '12345678901234',
          'denomination': 'CENTRE AUTOCLAIR',
          'distance_km': 12,
          'vehicle_category_id': 'VP',
          'vehicle_category_label': 'Véhicule particulier',
          'energy_category_id': 'GO',
          'energy_category_label': 'Gazole',
          'inspection_price': null,
        }),
        throwsFormatException,
      );
    });
  });
}
