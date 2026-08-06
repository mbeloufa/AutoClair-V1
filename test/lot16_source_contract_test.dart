import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 16 exposes vehicle storage from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains(
        "import '../../features/vehicle_storage/vehicle_storage_page.dart';",
      ),
    );
    expect(router, contains("path: '/vehicle-storage'"));
    expect(router, contains('const VehicleStoragePage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Gérer une immobilisation'"));
      expect(source, contains("route: '/vehicle-storage'"));
    }
    expect(home, contains("'Ouvrir les 23 outils'"));
    for (final label in [
      'départ',
      'immobilisation',
      'contrôle technique',
      'inspection',
    ]) {
      expect(home, contains(label));
    }
  });

  test('lot 16 remains structured and stores no storage location', () {
    final models = _read(
      'lib/features/vehicle_storage/vehicle_storage_models.dart',
    );
    final calculator = _read(
      'lib/features/vehicle_storage/vehicle_storage_calculator.dart',
    );
    final page = _read(
      'lib/features/vehicle_storage/vehicle_storage_page.dart',
    );

    expect(models, contains('enum VehicleStorageArea'));
    expect(models, contains('Map<VehicleStorageArea, VehicleStorageStatus>'));
    expect(models, contains('n’enregistre aucun lieu de stockage'));
    expect(calculator, contains('VehicleStorageLevel.blocked'));
    expect(page, contains("ValueKey('vehicle-storage-evaluate')"));
    expect(page, contains("'/vehicle-inspection'"));
    expect(page, contains("'/maintenance-planner'"));
    expect(page, contains("'/insurance-review'"));
    for (final forbidden in [
      'geolocator',
      'latitude',
      'longitude',
      'addressController',
      'storageLocation',
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

  test('lot 16 stores only a protected structured preparation', () {
    final service = _read(
      'lib/features/vehicle_storage/vehicle_storage_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806133000_vehicle_storage_v1.sql',
    );

    expect(service, contains('VehicleService'));
    expect(service, contains("from('vehicle_storage_checks')"));
    expect(service, contains("'vehicle-storage-v1'"));
    expect(service, isNot(contains('functions.invoke')));
    expect(service, isNot(contains('storage.from')));

    for (final value in [
      'vehicle_storage_checks',
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
      'storage_location',
      'photo_url',
      'third_party',
      'vin',
      'free_text',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 16 cumulative navigation exposes and tests storage', () {
    final actionTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final tripContract = _read('test/lot15_source_contract_test.dart');

    expect(actionTest, contains('Lot 4 to Lot 22'));
    expect(actionTest, contains('action-tool-/vehicle-storage'));
    expect(actionTest, contains('Immobilisation ouverte'));
    expect(actionTest, contains('tester.scrollUntilVisible'));
    expect(financialTest, contains("'/vehicle-storage'"));
    expect(financialTest, contains("'Gérer une immobilisation'"));
    expect(financialTest, contains("'Préparer mon contrôle technique'"));
    expect(navigationContract, contains('every Lot 4 to Lot 22 module'));
    expect(
      navigationContract,
      contains("'Gérer une immobilisation': '/vehicle-storage'"),
    );
    expect(tripContract, contains("'Ouvrir les 23 outils'"));
    expect(tripContract, contains('Lot 4 to Lot 22'));
  });

  test('lot 16 dart sources avoid known regressions', () {
    for (final path in [
      'lib/core/router/app_router.dart',
      'lib/features/home/action_center_page.dart',
      'lib/features/financial_tools/financial_tools_page.dart',
      'lib/features/vehicle_storage/vehicle_storage_models.dart',
      'lib/features/vehicle_storage/vehicle_storage_calculator.dart',
      'lib/features/vehicle_storage/vehicle_storage_service.dart',
      'lib/features/vehicle_storage/vehicle_storage_page.dart',
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
