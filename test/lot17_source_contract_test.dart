import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'lot 17 exposes technical control readiness from both navigation hubs',
    () {
      final router = _read('lib/core/router/app_router.dart');
      final center = _read('lib/features/home/action_center_page.dart');
      final financial = _read(
        'lib/features/financial_tools/financial_tools_page.dart',
      );
      final home = _read('lib/features/home/home_page.dart');

      expect(
        router,
        contains(
          "import '../../features/technical_control_readiness/technical_control_readiness_page.dart';",
        ),
      );
      expect(router, contains("path: '/technical-control-readiness'"));
      expect(router, contains('const TechnicalControlReadinessPage()'));
      for (final source in [center, financial]) {
        expect(source, contains("title: 'Préparer mon contrôle technique'"));
        expect(source, contains("route: '/technical-control-readiness'"));
      }
      expect(home, contains("'Ouvrir les 23 outils'"));
      for (final label in [
        'immobilisation',
        'contrôle technique',
        'inspection',
      ]) {
        expect(home, contains(label));
      }
    },
  );

  test('lot 17 remains structured and never guarantees the control result', () {
    final models = _read(
      'lib/features/technical_control_readiness/technical_control_readiness_models.dart',
    );
    final calculator = _read(
      'lib/features/technical_control_readiness/technical_control_readiness_calculator.dart',
    );
    final page = _read(
      'lib/features/technical_control_readiness/technical_control_readiness_page.dart',
    );

    expect(models, contains('enum TechnicalControlArea'));
    expect(
      models,
      contains('Map<TechnicalControlArea, TechnicalControlCheckStatus>'),
    );
    expect(models, contains('ne garantit pas le résultat'));
    expect(calculator, contains('TechnicalControlReadinessLevel.blocked'));
    expect(calculator, contains('completeness < 100 || score < 85'));
    expect(calculator, isNot(contains('completeness < 80 || score < 85')));
    expect(page, contains("ValueKey('technical-control-readiness-evaluate')"));
    expect(page, contains('showDatePicker('));
    expect(page, contains('context: context,'));
    expect(page, isNot(contains('visitContext: context,')));
    expect(page, contains("'/technical-controls'"));
    expect(page, contains("'/vehicle-inspection'"));
    expect(page, contains("'/maintenance-planner'"));
    for (final forbidden in [
      'geolocator',
      'latitude',
      'longitude',
      'addressController',
      'functions.invoke',
      'storage.from',
    ]) {
      expect(
        '${models.toLowerCase()}${page.toLowerCase()}'.contains(
          forbidden.toLowerCase(),
        ),
        isFalse,
      );
    }
  });

  test('lot 17 stores only a protected structured preparation', () {
    final service = _read(
      'lib/features/technical_control_readiness/technical_control_readiness_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806134500_technical_control_readiness_v1.sql',
    );

    expect(service, contains('VehicleService'));
    expect(service, contains("from('technical_control_readiness_checks')"));
    expect(service, contains("'technical-control-readiness-v1'"));
    expect(service, isNot(contains('functions.invoke')));
    expect(service, isNot(contains('storage.from')));

    for (final value in [
      'technical_control_readiness_checks',
      'enable row level security',
      'user_id = auth.uid()',
      'public.autoclair_user_owns_vehicle(vehicle_id)',
    ]) {
      expect(migration, contains(value));
    }
    expect(
      RegExp(
        r'^\s*create\s+policy\s+',
        multiLine: true,
      ).allMatches(migration).length,
      3,
    );
    for (final forbidden in [
      'latitude',
      'longitude',
      'street_address',
      'photo_url',
      'third_party',
      'vin',
      'free_text',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 17 cumulative navigation exposes and tests technical control', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final storageContract = _read('test/lot16_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot 22'));
    expect(actionTest, contains('action-tool-/technical-control-readiness'));
    expect(actionTest, contains('Préparation contrôle technique ouverte'));
    expect(actionTest, contains('tester.scrollUntilVisible'));
    expect(financialTest, contains("'/technical-control-readiness'"));
    expect(financialTest, contains("'Préparer mon contrôle technique'"));
    expect(navigationContract, contains('every Lot 4 to Lot 22 module'));
    expect(
      navigationContract,
      contains(
        "'Préparer mon contrôle technique': '/technical-control-readiness'",
      ),
    );
    expect(storageContract, contains("'Ouvrir les 23 outils'"));
    expect(storageContract, contains('Lot 4 to Lot 22'));
  });

  test('lot 17 dart sources avoid known regressions', () {
    for (final path in [
      'lib/core/router/app_router.dart',
      'lib/features/home/action_center_page.dart',
      'lib/features/financial_tools/financial_tools_page.dart',
      'lib/features/technical_control_readiness/technical_control_readiness_models.dart',
      'lib/features/technical_control_readiness/technical_control_readiness_calculator.dart',
      'lib/features/technical_control_readiness/technical_control_readiness_service.dart',
      'lib/features/technical_control_readiness/technical_control_readiness_page.dart',
    ]) {
      final source = _read(path);
      expect(RegExp(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(source), isFalse);
      expect(
        RegExp(
          r'^\s*@override\s*\r?\n\s*@override',
          multiLine: true,
        ).hasMatch(source),
        isFalse,
      );
      expect(source, isNot(contains('ScaffoldMessenger.of(this.context)')));
      expect(RegExp(r'\brequired\s+this\.context\b').hasMatch(source), isFalse);
    }
  });
}

String _read(String relativePath) {
  return File(relativePath).readAsStringSync();
}
