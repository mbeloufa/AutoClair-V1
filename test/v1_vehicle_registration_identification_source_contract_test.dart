import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registration lookup uses the RapidAPI provider securely', () {
    final backend = File(
      'supabase/functions/identify-vehicle/index.ts',
    ).readAsStringSync();

    for (final fragment in [
      'API_PLAQUE_IMMATRICULATION_TOKEN',
      'api-de-plaque-d-immatriculation-france.p.rapidapi.com',
      '"x-rapidapi-host"',
      '"x-rapidapi-key"',
      r'`?plaque=${encodeURIComponent(plate)}`',
      '"plaque": plate',
    ]) {
      expect(backend, contains(fragment));
    }

    expect(backend, isNot(contains('api.apiplaqueimmatriculation.com/plaque')));
  });

  test('registration lookup supports both provider payload formats', () {
    final backend = File(
      'supabase/functions/identify-vehicle/index.ts',
    ).readAsStringSync();

    for (final fragment in [
      '"AWN_marque"',
      '"marque"',
      '"AWN_modele"',
      '"modele"',
      '"AWN_date_mise_en_circulation_us"',
      '"date_mise_en_circulation_us"',
      '"AWN_date_mise_en_circulation"',
      '"date_mise_en_circulation"',
      '"AWN_energie_description"',
      '"AWN_energie"',
      '"energie"',
    ]) {
      expect(backend, contains(fragment));
    }
  });

  test('registration lookup exposes only the data needed by Flutter', () {
    final backend = File(
      'supabase/functions/identify-vehicle/index.ts',
    ).readAsStringSync();

    for (final fragment in [
      'registration_number: plate',
      'make,',
      'model,',
      'vehicle_year: vehicleYear',
      'fuel_type: fuelType',
    ]) {
      expect(backend, contains(fragment));
    }

    expect(backend, isNot(contains('console.log')));
    expect(backend, isNot(contains('raw_response')));
    expect(backend, isNot(contains('owner_name')));
    expect(backend, isNot(contains('titulaire')));
  });

  test('registration lookup keeps manual fallback messages', () {
    final backend = File(
      'supabase/functions/identify-vehicle/index.ts',
    ).readAsStringSync();

    expect(
      RegExp('continuer manuellement').allMatches(backend).length,
      greaterThanOrEqualTo(4),
    );
    expect(backend, contains('"PROVIDER_NOT_CONFIGURED"'));
    expect(backend, contains('"PROVIDER_UNAVAILABLE"'));
  });
}
