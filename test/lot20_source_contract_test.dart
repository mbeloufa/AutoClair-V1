import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 20 exposes battery care from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains("import '../../features/battery_care/battery_care_page.dart';"),
    );
    expect(router, contains("path: '/battery-care'"));
    expect(router, contains('const BatteryCarePage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Suivre ma batterie'"));
      expect(source, contains("route: '/battery-care'"));
    }
    expect(home, contains("'Ouvrir les 22 outils'"));
    expect(home, contains('batterie'));
  });

  test('lot 20 remains declarative and never claims a battery diagnosis', () {
    final models = _read('lib/features/battery_care/battery_care_models.dart');
    final calculator = _read(
      'lib/features/battery_care/battery_care_calculator.dart',
    );
    final page = _read('lib/features/battery_care/battery_care_page.dart');

    expect(models, contains('enum BatteryCareArea'));
    expect(models, contains('BatteryCareArea.startingBehavior'));
    expect(models, contains('BatteryCareArea.dashboardWarnings'));
    expect(models, contains('ne diagnostique pas la batterie'));
    expect(calculator, contains('completeness < 100 || score < 88'));
    expect(calculator, contains("code: 'UNSAFE_TO_MOVE'"));
    expect(page, contains("ValueKey('battery-care-evaluate')"));
    expect(page, contains('ne mesure aucune tension'));
    expect(page, isNot(contains('12.6 V')));
    expect(page, isNot(contains('14.4 V')));
    expect(page, isNot(contains('brancher le câble')));
  });

  test('lot 20 stores only a protected structured battery check', () {
    final service = _read(
      'lib/features/battery_care/battery_care_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806143000_battery_care_v1.sql',
    );

    expect(service, contains("from('battery_care_checks')"));
    expect(service, contains("'battery-care-v1'"));
    expect(migration, contains('battery_care_checks'));
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
      'battery_brand',
      'battery_model',
      'serial_number',
      'voltage_value',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 20 cumulative navigation exposes and tests battery care', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final tireContract = _read('test/lot19_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot 21'));
    expect(actionTest, contains('action-tool-/battery-care'));
    expect(actionTest, contains('action-tool-/fluid-care'));
    expect(actionTest, contains('battery care action opens its direct route'));
    expect(financialTest, contains("'/battery-care'"));
    expect(navigationContract, contains('every Lot 4 to Lot 21 module'));
    expect(
      navigationContract,
      contains("'Suivre ma batterie': '/battery-care'"),
    );
    expect(tireContract, contains("'Ouvrir les 22 outils'"));
    expect(tireContract, contains('Lot 4 to Lot 21'));
  });

  test('lot 20 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/battery_care/battery_care_models.dart',
      'lib/features/battery_care/battery_care_calculator.dart',
      'lib/features/battery_care/battery_care_service.dart',
      'lib/features/battery_care/battery_care_page.dart',
    ]) {
      final source = _read(path);
      expect(source, isNot(contains('visitContext: context')));
      expect(source, isNot(contains('Duration(hours: 24)')));
      expect(source, isNot(contains('functions.invoke')));
    }
    final page = _read('lib/features/battery_care/battery_care_page.dart');
    expect(page, contains('context: context,'));
  });
}

String _read(String path) => File(path).readAsStringSync();
