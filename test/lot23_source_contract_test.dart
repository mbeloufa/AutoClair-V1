import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 23 exposes brake care from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains("import '../../features/brake_care/brake_care_page.dart';"),
    );
    expect(router, contains("path: '/brake-care'"));
    expect(router, contains('const BrakeCarePage()'));
    for (final source in [center, financial]) {
      expect(
        source,
        contains("title: 'Surveiller freinage et tenue de route'"),
      );
      expect(source, contains("route: '/brake-care'"));
    }
    expect(home, contains("'Ouvrir les 24 outils'"));
    expect(home, contains('freinage'));
  });

  test('lot 23 remains declarative and never claims a brake diagnosis', () {
    final models = _read('lib/features/brake_care/brake_care_models.dart');
    final calculator = _read(
      'lib/features/brake_care/brake_care_calculator.dart',
    );
    final page = _read('lib/features/brake_care/brake_care_page.dart');

    expect(models, contains('enum BrakeCareArea'));
    expect(models, contains('BrakeCareStatus.notApplicable'));
    expect(models, contains('ne diagnostique aucun système de freinage'));
    expect(models, contains('ne mesure'));
    expect(calculator, contains('completeness < 100 || score < 88'));
    expect(calculator, contains("code: 'UNSAFE_TO_MOVE'"));
    expect(page, contains("ValueKey('brake-care-evaluate')"));
    expect(page, contains('ne diagnostique aucun système de freinage'));
    for (final forbidden in [
      '1,6 mm',
      '30 mètres',
      '50 mètres',
      'couple de serrage',
      'purger le circuit',
    ]) {
      expect(page, isNot(contains(forbidden)));
    }
  });

  test('lot 23 stores only a protected structured brake check', () {
    final service = _read('lib/features/brake_care/brake_care_service.dart');
    final migration = _read(
      'supabase/migrations/20260806151500_brake_care_v1.sql',
    );

    expect(service, contains("from('brake_care_checks')"));
    expect(service, contains("'brake-care-v1'"));
    expect(migration, contains('brake_care_checks'));
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains('public.autoclair_user_owns_vehicle(vehicle_id)'),
    );
    expect(
      RegExp(r'^create policy ', multiLine: true).allMatches(migration).length,
      3,
    );
    final sqlIdentifiers = RegExp(r'[a-z0-9_]+')
        .allMatches(migration.toLowerCase())
        .map((match) => match.group(0))
        .whereType<String>()
        .toSet();
    for (final forbidden in [
      'latitude',
      'longitude',
      'address',
      'part_number',
      'brake_brand',
      'pad_thickness',
      'stopping_distance',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(sqlIdentifiers, isNot(contains(forbidden)));
    }
  });

  test('lot 23 cumulative navigation exposes and tests brake care', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final visibilityContract = _read('test/lot22_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot 23'));
    expect(actionTest, contains('action-tool-/brake-care'));
    expect(actionTest, contains('brake care action opens its direct route'));
    expect(financialTest, contains("'/brake-care'"));
    expect(navigationContract, contains('every Lot 4 to Lot 23 module'));
    expect(
      navigationContract,
      contains("'Surveiller freinage et tenue de route': '/brake-care'"),
    );
    expect(visibilityContract, contains("path: '/visibility-care'"));
  });

  test('lot 23 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/brake_care/brake_care_models.dart',
      'lib/features/brake_care/brake_care_calculator.dart',
      'lib/features/brake_care/brake_care_service.dart',
      'lib/features/brake_care/brake_care_page.dart',
    ]) {
      final source = _read(path);
      expect(source, isNot(contains('visitContext: context')));
      expect(source, isNot(contains('Duration(hours: 24)')));
      expect(source, isNot(contains('functions.invoke')));
    }
    final page = _read('lib/features/brake_care/brake_care_page.dart');
    expect(page, contains('context: context,'));
  });
}

String _read(String path) => File(path).readAsStringSync();
