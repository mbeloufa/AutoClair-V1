import 'package:autoclair_app/features/vehicles/vehicle_identification_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads only the technical fields returned by the lookup gateway', () {
    final result = VehicleIdentificationResult.fromMap({
      'registration_number': 'AB-123-CD',
      'make': 'RENAULT',
      'model': 'CLIO',
      'vehicle_year': 2020,
      'fuel_type': 'Essence',
      'source_label': 'API Plaque Immatriculation',
      'ignored_owner_name': 'Should never be used',
      'ignored_vin': 'VF1XXXXXXXXXXXXXX',
    });

    expect(result.registrationNumber, 'AB-123-CD');
    expect(result.make, 'RENAULT');
    expect(result.model, 'CLIO');
    expect(result.vehicleYear, 2020);
    expect(result.fuelType, 'Essence');
    expect(result.displayName, 'RENAULT CLIO');
  });

  test('refuses an incomplete lookup result', () {
    expect(
      () => VehicleIdentificationResult.fromMap({
        'registration_number': 'AB-123-CD',
        'make': 'RENAULT',
      }),
      throwsFormatException,
    );
  });
}
