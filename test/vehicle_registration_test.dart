import 'package:autoclair_app/features/vehicles/vehicle_registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats modern French registrations', () {
    expect(VehicleRegistration.compact('ab-123-cd'), 'AB123CD');
    expect(VehicleRegistration.format('ab 123 cd'), 'AB-123-CD');
    expect(VehicleRegistration.isSupportedFrenchFormat('AB-123-CD'), isTrue);
  });

  test('formats legacy French registrations', () {
    expect(VehicleRegistration.format('1234 ab 75'), '1234 AB 75');
    expect(VehicleRegistration.isSupportedFrenchFormat('1234 AB 75'), isTrue);
  });

  test(
    'rejects unsupported lookup formats without blocking manual storage',
    () {
      expect(
        VehicleRegistration.lookupValidationMessage('not-a-plate'),
        contains('Format français attendu'),
      );
      expect(VehicleRegistration.lookupValidationMessage(''), isNotNull);
    },
  );
}
