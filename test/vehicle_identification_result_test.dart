import 'package:autoclair_app/features/vehicles/vehicle_identification_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads VIN and enriched technical data from the lookup gateway', () {
    final result = VehicleIdentificationResult.fromMap({
      'registration_number': 'GG-114-SK',
      'make': 'SKODA',
      'model': 'ENYAQ',
      'vehicle_year': 2022,
      'fuel_type': 'Électrique',
      'vin': 'TMBJC7NY5NF039349',
      'first_registration_date': '2022-06-03',
      'source_label': 'API Plaque Immatriculation',
      'profile_id': 'profile-1',
      'retrieved_at': '2026-08-10T16:00:00Z',
      'cached': false,
      'details': {
        'identity': {'version': '286 ELEMENT 85X', 'trim': '340 RS'},
        'technical': {
          'power_kw': 150,
          'fiscal_power': 5,
          'gearbox_type': 'AUTOMATIQUE',
        },
        'administrative': {'vehicle_category': 'M1'},
        'aftersales': {'k_type': '142230', 'sra_code': 'SK18050'},
        'media': {},
      },
    });

    expect(result.registrationNumber, 'GG-114-SK');
    expect(result.make, 'SKODA');
    expect(result.model, 'ENYAQ');
    expect(result.vehicleYear, 2022);
    expect(result.fuelType, 'Électrique');
    expect(result.vin, 'TMBJC7NY5NF039349');
    expect(result.firstRegistrationDate, '2022-06-03');
    expect(result.technical['power_kw'], 150);
    expect(result.aftersales['k_type'], '142230');
    expect(result.displayName, 'SKODA ENYAQ');
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
