import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 11 exposes the accident assistant from the financial hub', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');

    expect(
      router,
      contains(
        "import '../../features/accident_assistant/accident_assistant_page.dart';",
      ),
    );
    expect(router, contains("path: '/accident-assistant'"));
    expect(router, contains('const AccidentAssistantPage()'));
    expect(hub, contains("title: 'Gérer un accident'"));
    expect(hub, contains("route: '/accident-assistant'"));
  });

  test('lot 11 separates emergency, paper and e-constat scenarios', () {
    final models = _read(
      'lib/features/accident_assistant/accident_assistant_models.dart',
    );
    final calculator = _read(
      'lib/features/accident_assistant/accident_assistant_calculator.dart',
    );

    expect(calculator, contains('AccidentActionLevel.emergency'));
    expect(calculator, contains('AccidentActionLevel.paperReport'));
    expect(calculator, contains('AccidentActionLevel.electronicReport'));
    expect(calculator, contains('input.vehicleCount <= 2'));
    expect(calculator, contains('!input.foreignVehicle'));
    expect(calculator, contains('!input.otherPartyRefused'));
    expect(calculator, contains('_addWorkingDays(accidentDate, 5)'));
    expect(calculator, contains('derrière la glissière'));
    expect(calculator, contains('n’installez pas de triangle'));
    expect(models, contains('ne détermine jamais les responsabilités'));
  });

  test('lot 11 uses official e-constat access and the vehicle log', () {
    final page = _read(
      'lib/features/accident_assistant/accident_assistant_page.dart',
    );
    final service = _read(
      'lib/features/accident_assistant/accident_assistant_service.dart',
    );

    expect(
      page,
      contains('https://www.service-public.fr/particuliers/vosdroits/R68773'),
    );
    expect(page, contains('Appeler le 112'));
    expect(page, contains("normalized == '112'"));
    expect(page, contains(r"Uri.parse('tel:$normalized')"));
    expect(page, contains('Ouvrir e-constat'));
    expect(page, contains('Copier le résumé factuel'));
    expect(service, contains('_careService.recordEvent'));
    expect(service, contains("eventType: 'ACCIDENT'"));
    expect(service, contains("subcategoryCode: 'ACCIDENT_CLAIM'"));
    expect(service, isNot(contains('recordCost(')));
    expect(service, isNot(contains('recordOpportunity(')));
  });

  test('lot 11 stores no third-party identity or precise location', () {
    final migration = _read(
      'supabase/migrations/20260806070000_accident_assistant_v1.sql',
    );

    expect(migration, contains('vehicle_accident_profiles'));
    expect(migration, contains('vehicle_accident_cases'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('user_id = auth.uid()'));
    expect(
      migration,
      contains('public.autoclair_user_owns_vehicle(vehicle_id)'),
    );
    expect(_policyCount(migration), 7);

    final lower = migration.toLowerCase();
    for (final forbidden in [
      'third_party_name',
      'third_party_phone',
      'third_party_email',
      'third_party_address',
      'third_party_registration',
      'witness_name',
      'witness_phone',
      'latitude',
      'longitude',
      'exact_location',
      'free_text',
    ]) {
      expect(lower, isNot(contains(forbidden)));
    }
  });

  test('financial hub scrolls to the off-screen accident card', () {
    final responsive = _read('test/financial_tools_responsive_test.dart');

    expect(responsive, contains("'/accident-assistant'"));
    expect(responsive, contains("find.text('Gérer un accident')"));
    expect(responsive, contains('tester.scrollUntilVisible'));
    expect(responsive, contains('scrollable: scrollable'));
    expect(responsive, contains("find.text('Réviser mon assurance')"));
  });

  test('lot 11 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/accident_assistant/accident_assistant_models.dart',
      'lib/features/accident_assistant/accident_assistant_calculator.dart',
      'lib/features/accident_assistant/accident_assistant_service.dart',
      'lib/features/accident_assistant/accident_assistant_page.dart',
    ]) {
      final source = _read(path);
      expect(RegExp(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(source), isFalse);
      expect(source, isNot(contains('@override\n  @override')));
      expect(source, isNot(contains('ScaffoldMessenger.of(this.context)')));
      expect(
        source,
        isNot(contains('final AccidentAssistantProfile context;')),
      );
      expect(source, isNot(contains('required this.context')));
    }
  });
}

String _read(String relativePath) {
  return File(relativePath).readAsStringSync();
}

int _policyCount(String sql) {
  return RegExp(
    r'^\s*create\s+policy\s+',
    caseSensitive: false,
    multiLine: true,
  ).allMatches(sql).length;
}
