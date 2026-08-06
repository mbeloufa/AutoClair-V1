import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 22 exposes visibility care from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains(
        "import '../../features/visibility_care/visibility_care_page.dart';",
      ),
    );
    expect(router, contains("path: '/visibility-care'"));
    expect(router, contains('const VisibilityCarePage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Vérifier éclairage et visibilité'"));
      expect(source, contains("route: '/visibility-care'"));
    }
    expect(home, contains("'Ouvrir les 23 outils'"));
    expect(home, contains('visibilité'));
  });

  test('lot 22 remains declarative and avoids generic legal values', () {
    final models = _read(
      'lib/features/visibility_care/visibility_care_models.dart',
    );
    final calculator = _read(
      'lib/features/visibility_care/visibility_care_calculator.dart',
    );
    final page = _read(
      'lib/features/visibility_care/visibility_care_page.dart',
    );

    expect(models, contains('enum VisibilityCareArea'));
    expect(models, contains('VisibilityCareStatus.notApplicable'));
    expect(models, contains('diagnostique aucun circuit électrique'));
    expect(models, contains('ne garantit ni la conformité'));
    expect(calculator, contains('completeness < 100 || score < 88'));
    expect(calculator, contains("code: 'UNSAFE_TO_MOVE'"));
    expect(page, contains("ValueKey('visibility-care-evaluate')"));
    expect(page, contains('ne garantit pas la conformité'));
    for (final forbidden in [
      '1,6 mm',
      '55 W',
      'H7',
      'LED homologuée',
      'distance légale',
    ]) {
      expect(page, isNot(contains(forbidden)));
    }
  });

  test('lot 22 stores only a protected structured visibility check', () {
    final service = _read(
      'lib/features/visibility_care/visibility_care_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806150000_visibility_care_v1.sql',
    );

    expect(service, contains("from('visibility_care_checks')"));
    expect(service, contains("'visibility-care-v1'"));
    expect(migration, contains('visibility_care_checks'));
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
      'bulb_reference',
      'lamp_brand',
      'part_number',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(sqlIdentifiers, isNot(contains(forbidden)));
    }
  });

  test('lot 22 cumulative navigation exposes and tests visibility care', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final fluidContract = _read('test/lot21_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot 22'));
    expect(actionTest, contains('action-tool-/visibility-care'));
    expect(
      actionTest,
      contains('visibility care action opens its direct route'),
    );
    expect(financialTest, contains("'/visibility-care'"));
    expect(navigationContract, contains('every Lot 4 to Lot 22 module'));
    expect(
      navigationContract,
      contains("'Vérifier éclairage et visibilité': '/visibility-care'"),
    );
    expect(fluidContract, contains("'Ouvrir les 23 outils'"));
    expect(fluidContract, contains('Lot 4 to Lot 22'));
  });

  test('lot 22 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/visibility_care/visibility_care_models.dart',
      'lib/features/visibility_care/visibility_care_calculator.dart',
      'lib/features/visibility_care/visibility_care_service.dart',
      'lib/features/visibility_care/visibility_care_page.dart',
    ]) {
      final source = _read(path);
      expect(source, isNot(contains('visitContext: context')));
      expect(source, isNot(contains('Duration(hours: 24)')));
      expect(source, isNot(contains('functions.invoke')));
    }
    final page = _read(
      'lib/features/visibility_care/visibility_care_page.dart',
    );
    expect(page, contains('context: context,'));
  });
}

String _read(String path) => File(path).readAsStringSync();
