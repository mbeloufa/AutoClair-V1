import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 18 exposes workshop visit preparation from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains(
        "import '../../features/workshop_visit/workshop_visit_preparation_page.dart';",
      ),
    );
    expect(router, contains("path: '/workshop-visit'"));
    expect(router, contains('const WorkshopVisitPreparationPage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Préparer ma visite au garage'"));
      expect(source, contains("route: '/workshop-visit'"));
    }
    expect(home, contains("'Choisir une situation'"));
    for (final label in ['contrôle technique', 'garage', 'inspection']) {
      expect(home, contains(label));
    }
  });

  test('lot 18 remains structured and never claims a diagnosis', () {
    final models = _read(
      'lib/features/workshop_visit/workshop_visit_preparation_models.dart',
    );
    final calculator = _read(
      'lib/features/workshop_visit/workshop_visit_preparation_calculator.dart',
    );
    final page = _read(
      'lib/features/workshop_visit/workshop_visit_preparation_page.dart',
    );

    expect(models, contains('enum WorkshopPreparationArea'));
    expect(
      models,
      contains('Map<WorkshopPreparationArea, WorkshopPreparationStatus>'),
    );
    expect(models, contains('Il ne pose '));
    expect(models, contains('pas de diagnostic'));
    expect(models, contains('ni autorisation de travaux'));
    expect(calculator, contains('WorkshopPreparationLevel.urgent'));
    expect(calculator, contains('completeness < 100 || score < 85'));
    expect(page, contains("ValueKey('workshop-visit-evaluate')"));
    expect(page, contains('showDatePicker('));
    expect(page, contains('context: context,'));
    expect(page, contains("'/quote-comparison'"));
    expect(page, contains("'/history'"));
    expect(page, contains("'/maintenance-planner'"));
    for (final forbidden in [
      'geolocator',
      'latitude',
      'longitude',
      'addressController',
      'garageNameController',
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

  test('lot 18 stores only a protected structured preparation', () {
    final service = _read(
      'lib/features/workshop_visit/workshop_visit_preparation_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806140000_workshop_visit_preparation_v1.sql',
    );

    expect(service, contains('VehicleService'));
    expect(service, contains("from('workshop_visit_preparations')"));
    expect(service, contains("'workshop-visit-preparation-v1'"));
    expect(service, isNot(contains('functions.invoke')));
    expect(service, isNot(contains('storage.from')));

    for (final value in [
      'workshop_visit_preparations',
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
      'garage_name',
      'contact_name',
      'photo_url',
      'third_party',
      'vin',
      'free_text',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 18 cumulative navigation exposes and tests workshop visit', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final controlContract = _read('test/lot17_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot '));
    expect(actionTest, contains('action-tool-/workshop-visit'));
    expect(actionTest, contains('Préparation visite garage ouverte'));
    expect(actionTest, contains('tester.scrollUntilVisible'));
    expect(financialTest, contains("'/workshop-visit'"));
    expect(financialTest, contains("'Préparer ma visite au garage'"));
    expect(navigationContract, contains('every Lot 4 to Lot '));
    expect(
      navigationContract,
      contains("'Préparer ma visite au garage': '/workshop-visit'"),
    );
    expect(controlContract, contains("'Choisir une situation'"));
    expect(controlContract, contains('Lot 4 to Lot '));
  });

  test('lot 18 dart sources avoid known regressions', () {
    for (final path in [
      'lib/core/router/app_router.dart',
      'lib/features/home/action_center_page.dart',
      'lib/features/financial_tools/financial_tools_page.dart',
      'lib/features/workshop_visit/workshop_visit_preparation_models.dart',
      'lib/features/workshop_visit/workshop_visit_preparation_calculator.dart',
      'lib/features/workshop_visit/workshop_visit_preparation_service.dart',
      'lib/features/workshop_visit/workshop_visit_preparation_page.dart',
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
