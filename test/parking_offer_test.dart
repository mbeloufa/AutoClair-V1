import 'package:autoclair_app/features/parking/parking_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ParkingOffer parses a free park and ride', () {
    final offer = ParkingOffer.fromJson({
      'parking_id': 'way-123',
      'name': 'P+R Gare',
      'address': '1 avenue de la Gare, 21000 Dijon',
      'latitude': 47.322,
      'longitude': 5.0415,
      'distance_km': 2.4,
      'parking_type': 'surface',
      'access': 'yes',
      'fee': 'free',
      'capacity': 180,
      'disabled_spaces': 4,
      'charging_spaces': 6,
      'park_and_ride': true,
      'covered': false,
      'source_kind': 'facility',
      'opening_hours': '24/7',
    });

    expect(offer.displayName, 'P+R Gare');
    expect(offer.typeLabel, 'Parking de surface');
    expect(offer.feeLabel, 'Gratuit');
    expect(offer.capacityLabel, '180 places');
    expect(offer.hasAccessibleSpaces, isTrue);
    expect(offer.hasChargingSpaces, isTrue);
    expect(offer.parkAndRide, isTrue);
  });

  test('ParkingOffer keeps unknown information explicit', () {
    final offer = ParkingOffer.fromJson({
      'parking_id': 'node-456',
      'name': '',
      'address': '',
      'latitude': 47.32,
      'longitude': 5.04,
      'distance_km': 0.8,
      'parking_type': 'underground',
      'access': 'customers',
      'fee': 'unknown',
      'park_and_ride': false,
      'covered': true,
      'source_kind': 'entrance',
    });

    expect(offer.displayName, 'Entrée de parking');
    expect(offer.typeLabel, 'Parking souterrain');
    expect(offer.feeLabel, 'Tarif non renseigné');
    expect(offer.accessLabel, 'Réservé aux clients');
    expect(offer.capacity, isNull);
  });
}
