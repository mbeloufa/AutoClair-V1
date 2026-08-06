import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 14 exposes guided inspection from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains(
        "import '../../features/vehicle_inspection/vehicle_inspection_page.dart';",
      ),
    );
    expect(router, contains("path: '/vehicle-inspection'"));
    expect(router, contains('const VehicleInspectionPage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Inspecter mon véhicule'"));
      expect(source, contains("route: '/vehicle-inspection'"));
    }
    expect(home, contains("'Ouvrir les "));
    for (final label in [
      'vol',
      'départ',
      'immobilisation',
      'contrôle technique',
      'inspection',
      'risques',
      'achat',
    ]) {
      expect(home, contains(label));
    }
  });

  test('lot 14 remains structured and never claims an expertise', () {
    final models = _read(
      'lib/features/vehicle_inspection/vehicle_inspection_models.dart',
    );
    final calculator = _read(
      'lib/features/vehicle_inspection/vehicle_inspection_calculator.dart',
    );
    final page = _read(
      'lib/features/vehicle_inspection/vehicle_inspection_page.dart',
    );

    for (final value in [
      'VehicleInspectionArea.brakes',
      'VehicleInspectionArea.tires',
      'VehicleInspectionStatus.notChecked',
      'VehicleInspectionLevel.priority',
      'ne remplace ni un contrôle technique',
    ]) {
      expect(models, contains(value));
    }
    expect(calculator, contains('PURCHASE_ROAD_TEST_MISSING'));
    expect(calculator, contains('RETURN_PHOTOS_MISSING'));
    expect(page, contains("ValueKey('vehicle-inspection-submit')"));
    expect(page, contains("ValueKey('vehicle-inspection-result')"));
    expect(page, contains('pas les photos dans ce lot'));
    expect(page, isNot(contains('expertise automatique validée')));
  });

  test('lot 14 stores only a protected structured snapshot', () {
    final service = _read(
      'lib/features/vehicle_inspection/vehicle_inspection_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806123000_vehicle_inspection_v1.sql',
    );

    expect(service, contains('VehicleService'));
    expect(service, contains("from('vehicle_inspections')"));
    expect(service, contains("'vehicle-inspection-v1'"));
    expect(service, isNot(contains('functions.invoke')));
    expect(service, isNot(contains('storage.from')));

    for (final value in [
      'vehicle_inspections',
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
      'vin',
      'latitude',
      'longitude',
      'street_address',
      'free_text',
      'photo_url',
      'third_party',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 14 cumulative navigation exposes and tests inspection', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final riskContract = _read('test/lot13_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot '));
    expect(actionTest, contains("action-tool-/vehicle-inspection"));
    expect(actionTest, contains('Inspection ouverte'));
    expect(financialTest, contains("'/vehicle-inspection'"));
    expect(financialTest, contains("'Inspecter mon véhicule'"));
    expect(financialTest, contains("'Préparer mon départ'"));
    expect(financialTest, contains("'Gérer une immobilisation'"));
    expect(financialTest, contains("'Préparer mon contrôle technique'"));
    expect(navigationContract, contains('every Lot 4 to Lot '));
    expect(
      navigationContract,
      contains("'Inspecter mon véhicule': '/vehicle-inspection'"),
    );
    expect(riskContract, contains("'Ouvrir les "));
    expect(riskContract, contains('every Lot 4 to Lot '));
  });

  test('lot 14 dart sources avoid known regressions', () {
    for (final path in [
      'lib/core/router/app_router.dart',
      'lib/features/home/action_center_page.dart',
      'lib/features/financial_tools/financial_tools_page.dart',
      'lib/features/vehicle_inspection/vehicle_inspection_models.dart',
      'lib/features/vehicle_inspection/vehicle_inspection_calculator.dart',
      'lib/features/vehicle_inspection/vehicle_inspection_service.dart',
      'lib/features/vehicle_inspection/vehicle_inspection_page.dart',
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
