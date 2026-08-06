import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 15 exposes departure readiness from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains(
        "import '../../features/trip_readiness/trip_readiness_page.dart';",
      ),
    );
    expect(router, contains("path: '/trip-readiness'"));
    expect(router, contains('const TripReadinessPage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Préparer mon départ'"));
      expect(source, contains("route: '/trip-readiness'"));
    }
    expect(home, contains("'Ouvrir les 17 outils'"));
    for (final label in ['vol', 'départ', 'immobilisation', 'inspection']) {
      expect(home, contains(label));
    }
  });

  test('lot 15 remains structured and stores no route or destination', () {
    final models = _read(
      'lib/features/trip_readiness/trip_readiness_models.dart',
    );
    final calculator = _read(
      'lib/features/trip_readiness/trip_readiness_calculator.dart',
    );
    final page = _read('lib/features/trip_readiness/trip_readiness_page.dart');

    expect(models, contains('enum TripReadinessArea'));
    expect(models, contains('Map<TripReadinessArea, TripCheckStatus>'));
    expect(models, contains('n’enregistre ni destination ni itinéraire'));
    expect(calculator, contains('TripReadinessLevel.blocked'));
    expect(page, contains("ValueKey('trip-readiness-evaluate')"));
    expect(page, contains("'/vehicle-inspection'"));
    expect(page, contains("'/maintenance-planner'"));
    expect(page, contains("'/breakdown-assistant'"));
    for (final forbidden in [
      'geolocator',
      'latitude',
      'longitude',
      'destinationController',
      'routePolyline',
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

  test('lot 15 stores only a protected structured preparation', () {
    final service = _read(
      'lib/features/trip_readiness/trip_readiness_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806130000_trip_readiness_v1.sql',
    );

    expect(service, contains('VehicleService'));
    expect(service, contains("from('trip_readiness_checks')"));
    expect(service, contains("'trip-readiness-v1'"));
    expect(service, isNot(contains('functions.invoke')));
    expect(service, isNot(contains('storage.from')));

    for (final value in [
      'trip_readiness_checks',
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
      'destination',
      'latitude',
      'longitude',
      'street_address',
      'itinerary',
      'photo_url',
      'third_party',
      'vin',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test(
    'lot 15 cumulative navigation exposes and tests departure readiness',
    () {
      final actionTest = _read('test/action_center_responsive_test.dart');
      final financialTest = _read('test/financial_tools_responsive_test.dart');
      final navigationContract = _read(
        'test/lot11_5_source_contract_test.dart',
      );
      final riskContract = _read('test/lot13_source_contract_test.dart');
      final inspectionContract = _read('test/lot14_source_contract_test.dart');

      expect(actionTest, contains('Lot 4 to Lot 16'));
      expect(actionTest, contains('action-tool-/trip-readiness'));
      expect(actionTest, contains('Préparation du départ ouverte'));
      expect(financialTest, contains("'/trip-readiness'"));
      expect(financialTest, contains("'Préparer mon départ'"));
      expect(financialTest, contains("'Gérer une immobilisation'"));
      expect(navigationContract, contains('every Lot 4 to Lot 16 module'));
      expect(navigationContract, contains('allMatches(center).length, 17'));
      expect(riskContract, contains("'Ouvrir les 17 outils'"));
      expect(inspectionContract, contains('Lot 4 to Lot 16'));
    },
  );

  test('lot 15 dart sources avoid known regressions', () {
    for (final path in [
      'lib/core/router/app_router.dart',
      'lib/features/home/action_center_page.dart',
      'lib/features/financial_tools/financial_tools_page.dart',
      'lib/features/trip_readiness/trip_readiness_models.dart',
      'lib/features/trip_readiness/trip_readiness_calculator.dart',
      'lib/features/trip_readiness/trip_readiness_service.dart',
      'lib/features/trip_readiness/trip_readiness_page.dart',
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
