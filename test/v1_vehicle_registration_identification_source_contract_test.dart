import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'registration identification prefills VIN and keeps all useful groups',
    () {
      final page = _read('lib/features/vehicles/vehicle_form_page.dart');
      final result = _read(
        'lib/features/vehicles/vehicle_identification_result.dart',
      );
      final card = _read(
        'lib/features/vehicles/vehicle_registration_identification_card.dart',
      );

      expect(page, contains('_vinController.text = result.vin!'));
      expect(page, contains('sans nouvel appel payant'));
      expect(result, contains('final String? vin;'));
      expect(result, contains('final Map<String, dynamic> technical;'));
      expect(result, contains('final Map<String, dynamic> aftersales;'));
      expect(card, contains('Voir les caractéristiques récupérées'));
      expect(card, contains('VehicleIdentificationDetailsView'));
    },
  );

  test(
    'RapidAPI gateway stores a fixed allowlist including VIN and specialist identifiers',
    () {
      final backend = _read('supabase/functions/identify-vehicle/index.ts');

      for (final fragment in [
        'API_PLAQUE_IMMATRICULATION_TOKEN',
        'api-de-plaque-d-immatriculation-france.p.rapidapi.com',
        'AWN_VIN',
        'AWN_k_type',
        'AWN_codes_sra',
        'AWN_codes_moteur',
        'AWN_tecdoc_modele_id',
        'AWN_puissance_KW',
        'AWN_type_boite_vites',
        'AWN_date_mise_en_circulation_us',
        'providerFieldAllowlist',
        'vehicle_identification_profiles',
      ]) {
        expect(backend, contains(fragment));
      }

      expect(backend, isNot(contains('console.log')));
      expect(backend, isNot(contains('owner_name')));
      expect(backend, isNot(contains('titulaire')));
    },
  );

  test('gateway reuses a recent stored identification before a paid call', () {
    final backend = _read('supabase/functions/identify-vehicle/index.ts');
    final fetchPosition = backend.indexOf('providerResponse = await fetch');
    final cachePosition = backend.indexOf('cachedProfile');

    expect(cachePosition, greaterThanOrEqualTo(0));
    expect(fetchPosition, greaterThan(cachePosition));
    expect(backend, contains('CACHE_MAX_AGE_MS'));
    expect(backend, contains('force_refresh'));
  });

  test('saved vehicle screen reuses the persisted technical profile', () {
    final page = _read('lib/features/vehicle_care/vehicle_care_page.dart');
    final service = _read(
      'lib/features/vehicles/vehicle_identification_profile_service.dart',
    );
    final card = _read(
      'lib/features/vehicles/vehicle_identification_profile_card.dart',
    );

    expect(page, contains('VehicleIdentificationProfileCard'));
    expect(page, contains('_loadIdentificationProfile'));
    expect(service, contains("from('vehicle_identification_profiles')"));
    expect(card, contains('Caractéristiques du véhicule'));
  });

  test(
    'migration protects profiles with RLS and links them to saved vehicles',
    () {
      final migration = _read(
        'supabase/migrations/20260810181500_vehicle_identification_profiles_v1.sql',
      );

      expect(migration, contains('enable row level security'));
      expect(migration, contains('vehicle_identification_profiles_select_own'));
      expect(migration, contains('grant select'));
      expect(
        migration,
        contains('autoclair_link_vehicle_identification_profile'),
      );
      expect(
        migration,
        contains('unique (user_id, registration_key, provider)'),
      );
    },
  );
}
