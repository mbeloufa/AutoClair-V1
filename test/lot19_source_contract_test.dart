import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 19 exposes tire care from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains("import '../../features/tire_care/tire_care_page.dart';"),
    );
    expect(router, contains("path: '/tire-care'"));
    expect(router, contains('const TireCarePage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Suivre mes pneus'"));
      expect(source, contains("route: '/tire-care'"));
    }
    expect(home, contains("'Ouvrir les 22 outils'"));
    expect(home, contains('pneus'));
  });

  test('lot 19 remains structured and avoids generic pressure values', () {
    final models = _read('lib/features/tire_care/tire_care_models.dart');
    final calculator = _read(
      'lib/features/tire_care/tire_care_calculator.dart',
    );
    final page = _read('lib/features/tire_care/tire_care_page.dart');

    expect(models, contains('enum TireCareArea'));
    expect(models, contains('TireCareArea.pressureReference'));
    expect(models, contains('TireCareArea.sidewalls'));
    expect(models, contains('TireCareArea.visibleTread'));
    expect(models, contains('aucune pression constructeur'));
    expect(calculator, contains('completeness < 100 || score < 88'));
    expect(calculator, contains("code: 'UNSAFE_TO_MOVE'"));
    expect(page, contains("ValueKey('tire-care-evaluate')"));
    expect(page, contains('ne fixe aucune pression constructeur'));
    expect(page, isNot(contains('2.2 bar')));
    expect(page, isNot(contains('1,6 mm')));
  });

  test('lot 19 stores only a protected structured tire check', () {
    final service = _read('lib/features/tire_care/tire_care_service.dart');
    final migration = _read(
      'supabase/migrations/20260806141500_tire_care_v1.sql',
    );

    expect(service, contains("from('tire_care_checks')"));
    expect(service, contains("'tire-care-v1'"));
    expect(migration, contains('tire_care_checks'));
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains('public.autoclair_user_owns_vehicle(vehicle_id)'),
    );
    expect(
      RegExp(r'^create policy ', multiLine: true).allMatches(migration).length,
      3,
    );
    for (final forbidden in [
      'latitude',
      'longitude',
      'address',
      'tire_brand',
      'dot_code',
      'pressure_value',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 19 cumulative navigation exposes and tests tire care', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final workshopContract = _read('test/lot18_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot 21'));
    expect(actionTest, contains('action-tool-/tire-care'));
    expect(actionTest, contains('tire care action opens its direct route'));
    expect(financialTest, contains("'/tire-care'"));
    expect(navigationContract, contains('every Lot 4 to Lot 21 module'));
    expect(navigationContract, contains("'Suivre mes pneus': '/tire-care'"));
    expect(workshopContract, contains("'Ouvrir les 22 outils'"));
    expect(workshopContract, contains('Lot 4 to Lot 21'));
  });

  test('lot 19 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/tire_care/tire_care_models.dart',
      'lib/features/tire_care/tire_care_calculator.dart',
      'lib/features/tire_care/tire_care_service.dart',
      'lib/features/tire_care/tire_care_page.dart',
    ]) {
      final source = _read(path);
      expect(source, isNot(contains('visitContext: context')));
      expect(source, isNot(contains('Duration(hours: 24)')));
      expect(source, isNot(contains('functions.invoke')));
    }
    final page = _read('lib/features/tire_care/tire_care_page.dart');
    expect(page, contains('context: context,'));
  });
}

String _read(String path) => File(path).readAsStringSync();
