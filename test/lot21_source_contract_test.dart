import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 21 exposes fluid care from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains("import '../../features/fluid_care/fluid_care_page.dart';"),
    );
    expect(router, contains("path: '/fluid-care'"));
    expect(router, contains('const FluidCarePage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Suivre mes niveaux'"));
      expect(source, contains("route: '/fluid-care'"));
    }
    expect(home, contains("'Ouvrir les 23 outils'"));
    expect(home, contains('niveaux'));
  });

  test('lot 21 remains declarative and avoids generic fluid values', () {
    final models = _read('lib/features/fluid_care/fluid_care_models.dart');
    final calculator = _read(
      'lib/features/fluid_care/fluid_care_calculator.dart',
    );
    final page = _read('lib/features/fluid_care/fluid_care_page.dart');

    expect(models, contains('enum FluidCareArea'));
    expect(models, contains('FluidCareStatus.notApplicable'));
    expect(models, contains('Il ne mesure '));
    expect(models, contains('aucun niveau'));
    expect(models, contains('ne diagnostique aucune fuite'));
    expect(calculator, contains('completeness < 100 || score < 88'));
    expect(calculator, contains("code: 'UNSAFE_TO_MOVE'"));
    expect(page, contains("ValueKey('fluid-care-evaluate')"));
    expect(page, contains('ne recommande aucun produit générique'));
    for (final forbidden in [
      '5W30',
      '10W40',
      '1 litre',
      'niveau MAX',
      'niveau MIN',
    ]) {
      expect(page, isNot(contains(forbidden)));
    }
  });

  test('lot 21 stores only a protected structured fluid check', () {
    final service = _read('lib/features/fluid_care/fluid_care_service.dart');
    final migration = _read(
      'supabase/migrations/20260806144500_fluid_care_v1.sql',
    );

    expect(service, contains("from('fluid_care_checks')"));
    expect(service, contains("'fluid-care-v1'"));
    expect(migration, contains('fluid_care_checks'));
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
      'fluid_brand',
      'product_reference',
      'quantity_value',
      'viscosity_grade',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 21 cumulative navigation exposes and tests fluid care', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final batteryContract = _read('test/lot20_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot 22'));
    expect(actionTest, contains('action-tool-/fluid-care'));
    expect(actionTest, contains('action-tool-/visibility-care'));
    expect(actionTest, contains('fluid care action opens its direct route'));
    expect(financialTest, contains("'/fluid-care'"));
    expect(navigationContract, contains('every Lot 4 to Lot 22 module'));
    expect(navigationContract, contains("'Suivre mes niveaux': '/fluid-care'"));
    expect(batteryContract, contains("'Ouvrir les 23 outils'"));
    expect(batteryContract, contains('Lot 4 to Lot 22'));
  });

  test('lot 21 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/fluid_care/fluid_care_models.dart',
      'lib/features/fluid_care/fluid_care_calculator.dart',
      'lib/features/fluid_care/fluid_care_service.dart',
      'lib/features/fluid_care/fluid_care_page.dart',
    ]) {
      final source = _read(path);
      expect(source, isNot(contains('visitContext: context')));
      expect(source, isNot(contains('Duration(hours: 24)')));
      expect(source, isNot(contains('functions.invoke')));
    }
    final page = _read('lib/features/fluid_care/fluid_care_page.dart');
    expect(page, contains('context: context,'));
  });
}

String _read(String path) => File(path).readAsStringSync();
