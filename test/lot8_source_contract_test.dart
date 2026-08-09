import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('lot 8 exposes the breakdown assistant from the financial hub', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final page = _read(
      'lib/features/breakdown_assistant/breakdown_assistant_page.dart',
    );

    expect(router, contains("path: '/breakdown-assistant'"));
    expect(hub, contains("title: 'Gérer une panne'"));
    expect(hub, contains("route: '/breakdown-assistant'"));
    expect(page, contains('Commencez toujours par sécuriser les personnes'));
    expect(page, contains('Appeler le 112'));
    expect(page, contains('Préparer un SMS au 114'));
    expect(page, contains('Ajouter l’incident au carnet'));
  });

  test('lot 8 follows official motorway safety principles', () {
    final calculator = _read(
      'lib/features/breakdown_assistant/breakdown_assistant_calculator.dart',
    );

    expect(calculator, contains('derrière la glissière'));
    expect(calculator, contains('borne orange'));
    expect(calculator, contains('côté passager'));
    expect(calculator, contains('N’installez pas le triangle sur autoroute'));
    expect(calculator, contains('ne traversez jamais les voies'));
    expect(calculator, contains('appelez le 112'));
  });

  test('lot 8 stores no location coordinates and protects data with RLS', () {
    final migration = _read(
      'supabase/migrations/20260805220000_breakdown_assistant_v1.sql',
    );

    expect(migration, contains('vehicle_breakdown_profiles'));
    expect(migration, contains('vehicle_breakdown_cases'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('user_id = auth.uid()'));
    expect(migration, contains('autoclair_user_owns_vehicle(vehicle_id)'));
    expect(migration.toLowerCase(), isNot(contains('latitude')));
    expect(migration.toLowerCase(), isNot(contains('longitude')));
    expect(migration.toLowerCase(), isNot(contains('route_points')));
  });

  test('lot 8 reuses the vehicle log without creating an expense', () {
    final service = _read(
      'lib/features/breakdown_assistant/breakdown_assistant_service.dart',
    );

    expect(service, contains('_careService.recordEvent'));
    expect(service, contains("status: 'COMPLETED'"));
    expect(service, contains('timeline_event_id'));
    expect(service, isNot(contains('recordCost(')));
    expect(service, isNot(contains('recordOpportunity(')));
  });

  test('financial hub scrolls to the off-screen breakdown card', () {
    final responsiveTest = _read('test/financial_tools_responsive_test.dart');

    expect(responsiveTest, contains("'/breakdown-assistant'"));
    expect(responsiveTest, contains("'Gérer une panne'"));
    expect(responsiveTest, contains('tester.scrollUntilVisible'));
  });

  test('lot 8 dart sources avoid known lint regressions', () {
    final featureDirectory = Directory('lib/features/breakdown_assistant');
    for (final entity in featureDirectory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      expect(
        RegExp(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(content),
        isFalse,
        reason: entity.path,
      );
      expect(
        RegExp(r'@override\s+@override').hasMatch(content),
        isFalse,
        reason: entity.path,
      );
    }
  });
}
