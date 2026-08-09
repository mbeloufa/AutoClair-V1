import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'Lot 7 integrates registration identification without removing manual edit',
    () {
      final page = _read('lib/features/vehicles/vehicle_form_page.dart');
      final card = _read(
        'lib/features/vehicles/vehicle_registration_identification_card.dart',
      );
      final service = _read(
        'lib/features/vehicles/vehicle_identification_service.dart',
      );

      expect(page, contains('VehicleRegistrationIdentificationCard'));
      expect(page, contains('_applyIdentifiedVehicle'));
      expect(page, contains('VehicleBrandCatalog.canonicalValue'));
      expect(page, contains("labelText: 'VIN'"));

      expect(card, contains('Identifier mon véhicule'));
      expect(card, contains('Vous gardez la main avant l’enregistrement.'));
      expect(card, contains('saisie manuelle toujours possible'));

      expect(service, contains("'identify-vehicle'"));
      expect(service, contains('Vous pouvez continuer manuellement.'));
    },
  );

  test('Lot 7 lookup gateway minimizes returned vehicle data', () {
    final function = _read('supabase/functions/identify-vehicle/index.ts');

    expect(function, contains('API_PLAQUE_IMMATRICULATION_TOKEN'));
    expect(function, contains('api.apiplaqueimmatriculation.com/plaque'));
    expect(function, contains('registration_number: registration'));
    expect(function, contains('make,'));
    expect(function, contains('model,'));
    expect(function, contains('vehicle_year: parseYear(data)'));
    expect(function, contains('fuel_type: normalizeFuel(data.energieNGC)'));

    expect(function, isNot(contains('owner_name')));
    expect(function, isNot(contains('titulaire')));
    expect(function, isNot(contains('adresse')));
    expect(function, isNot(contains('vin:')));
    expect(function, isNot(contains('console.log')));
  });
}
