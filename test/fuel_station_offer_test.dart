import 'package:autoclair_app/features/fuel_prices/fuel_station_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FuelStationOffer parses an available station', () {
    final offer = FuelStationOffer.fromJson({
      'station_id': '21000001',
      'address': '1 rue de Dijon',
      'postal_code': '21000',
      'city': 'Dijon',
      'latitude': 47.322,
      'longitude': 5.0415,
      'distance_km': 3.25,
      'fuel_type': 'E10',
      'price': 1.789,
      'price_updated_at': '2026-08-03T08:00:00Z',
      'availability': 'available',
      'automate_24h': true,
      'services': ['Lavage automatique'],
      'source_fetched_at': '2026-08-03T08:05:00Z',
    });

    expect(offer.stationId, '21000001');
    expect(offer.fullAddress, '1 rue de Dijon, 21000 Dijon');
    expect(offer.isAvailable, isTrue);
    expect(offer.price, 1.789);
    expect(offer.automate24h, isTrue);
    expect(offer.services, ['Lavage automatique']);
  });

  test('FuelStationOffer parses a temporary outage without price', () {
    final offer = FuelStationOffer.fromJson({
      'station_id': '21000002',
      'address': '',
      'postal_code': '21000',
      'city': 'Dijon',
      'latitude': 47.32,
      'longitude': 5.04,
      'distance_km': 2,
      'fuel_type': 'Gazole',
      'price': null,
      'availability': 'temporary_outage',
      'outage_started_at': '2026-08-03T07:00:00Z',
      'automate_24h': false,
      'services': [],
    });

    expect(offer.isAvailable, isFalse);
    expect(offer.isTemporaryOutage, isTrue);
    expect(offer.price, isNull);
  });
}
