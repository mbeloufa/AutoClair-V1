import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vehicle parses an exact first registration date', () {
    final vehicle = Vehicle.fromJson(
      _vehicleJson(firstRegistrationDate: '2021-06-17'),
    );

    expect(vehicle.firstRegistrationDate, DateTime(2021, 6, 17));
  });

  test('vehicle keeps first registration date optional', () {
    final vehicle = Vehicle.fromJson(_vehicleJson());

    expect(vehicle.firstRegistrationDate, isNull);
  });
}

Map<String, dynamic> _vehicleJson({String? firstRegistrationDate}) {
  final json = <String, dynamic>{
    'id': 'vehicle-1',
    'user_id': 'user-1',
    'make': 'Volkswagen',
    'model': 'Golf',
    'is_primary': true,
    'created_at': '2026-08-10T10:00:00Z',
    'updated_at': '2026-08-10T10:00:00Z',
  };
  if (firstRegistrationDate != null) {
    json['first_registration_date'] = firstRegistrationDate;
  }
  return json;
}
