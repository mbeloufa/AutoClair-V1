import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vehicle.fromJson construit le véhicule', () {
    final vehicle = Vehicle.fromJson({
      'id': 'vehicle-1',
      'user_id': 'user-1',
      'nickname': 'Ma Golf',
      'make': 'Volkswagen',
      'model': 'Golf',
      'vehicle_year': 2020,
      'fuel_type': 'Essence',
      'mileage': 85000,
      'registration_number': 'AB-123-CD',
      'vin': 'WVWZZZ1KZAW063297',
      'is_primary': true,
      'created_at': '2026-08-01T10:00:00.000Z',
      'updated_at': '2026-08-01T10:00:00.000Z',
    });

    expect(vehicle.displayName, 'Ma Golf');
    expect(vehicle.makeAndModel, 'Volkswagen Golf');
    expect(vehicle.vehicleYear, 2020);
    expect(vehicle.isPrimary, isTrue);
  });

  test('Vehicle.displayName utilise marque et modèle sans surnom', () {
    final vehicle = Vehicle.fromJson({
      'id': 'vehicle-1',
      'user_id': 'user-1',
      'nickname': null,
      'make': 'Peugeot',
      'model': '308',
      'vehicle_year': null,
      'fuel_type': null,
      'mileage': null,
      'registration_number': null,
      'vin': null,
      'is_primary': false,
      'created_at': '2026-08-01T10:00:00.000Z',
      'updated_at': '2026-08-01T10:00:00.000Z',
    });

    expect(vehicle.displayName, 'Peugeot 308');
  });
}
