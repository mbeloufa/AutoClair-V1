import 'package:autoclair_app/features/vehicles/vehicle_identification_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a persisted enriched vehicle identification profile', () {
    final profile = VehicleIdentificationProfile.fromMap({
      'id': 'profile-1',
      'vehicle_id': 'vehicle-1',
      'registration_number': 'GG-114-SK',
      'vin': 'TMBJC7NY5NF039349',
      'source_label': 'API Plaque Immatriculation',
      'retrieved_at': '2026-08-10T16:00:00Z',
      'identity': {'version': '286 ELEMENT 85X'},
      'technical': {'power_kw': 150},
      'administrative': {'vehicle_category': 'M1'},
      'aftersales': {'k_type': '142230'},
      'media': {},
    });

    expect(profile.vin, 'TMBJC7NY5NF039349');
    expect(profile.technical['power_kw'], 150);
    expect(profile.aftersales['k_type'], '142230');
  });
}
