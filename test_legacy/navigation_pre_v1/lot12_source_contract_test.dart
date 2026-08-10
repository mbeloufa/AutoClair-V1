import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 12 exposes the theft assistant from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains(
        "import '../../features/theft_assistant/theft_assistant_page.dart';",
      ),
    );
    expect(router, contains("path: '/theft-assistant'"));
    expect(router, contains('const TheftAssistantPage()'));
    expect(hub, contains("title: 'Réagir à un vol'"));
    expect(hub, contains("route: '/theft-assistant'"));
    expect(center, contains("title: 'Réagir à un vol'"));
    expect(center, contains("route: '/theft-assistant'"));
    expect(home, contains("'Moments clés'"));
    expect(home, contains("context.push<void>('/actions')"));
  });

  test('lot 12 applies police, impound and insurer rules', () {
    final models = _read(
      'lib/features/theft_assistant/theft_assistant_models.dart',
    );
    final calculator = _read(
      'lib/features/theft_assistant/theft_assistant_calculator.dart',
    );

    expect(models, contains('TheftIncidentType.vehicleTheft'));
    expect(models, contains('TheftIncidentType.vandalism'));
    expect(calculator, contains('TheftActionLevel.emergency'));
    expect(calculator, contains('TheftActionLevel.checkImpound'));
    expect(calculator, contains('_addWorkingDays'));
    expect(calculator, contains('theftDeadline ? 2 : 5'));
    expect(calculator, contains('ne confrontez personne'));
    expect(calculator, contains('fourrière'));
    expect(calculator, contains('Ne tentez pas de récupérer seul'));
  });

  test('lot 12 opens official services and reuses the vehicle log', () {
    final page = _read(
      'lib/features/theft_assistant/theft_assistant_page.dart',
    );
    final service = _read(
      'lib/features/theft_assistant/theft_assistant_service.dart',
    );

    expect(
      page,
      contains(
        'https://www.service-public.fr/particuliers/vosdroits/F34300/22',
      ),
    );
    expect(
      page,
      contains(
        'https://aab.plainte-en-ligne.masecurite.interieur.gouv.fr/accueil',
      ),
    );
    expect(page, contains('Appeler le 17'));
    expect(page, contains("normalized != '17'"));
    expect(page, contains(r"Uri.parse('tel:$normalized')"));
    expect(page, contains('Ouvrir Plainte en ligne'));
    expect(page, contains('Copier le résumé factuel'));
    expect(service, contains('_careService.recordEvent'));
    expect(service, contains("eventType: 'INSURANCE'"));
    expect(service, contains("subcategoryCode: 'INSURANCE'"));
    expect(service, isNot(contains('recordCost(')));
    expect(service, isNot(contains('recordOpportunity(')));
  });

  test('lot 12 stores no author identity or precise location', () {
    final migration = _read(
      'supabase/migrations/20260806073000_theft_assistant_v1.sql',
    );

    expect(migration, contains('vehicle_theft_profiles'));
    expect(migration, contains('vehicle_theft_cases'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('user_id = auth.uid()'));
    expect(
      migration,
      contains('public.autoclair_user_owns_vehicle(vehicle_id)'),
    );
    expect(_policyCount(migration), 7);

    final lower = migration.toLowerCase();
    for (final forbidden in [
      'author_name',
      'author_phone',
      'author_email',
      'author_address',
      'witness_name',
      'witness_phone',
      'latitude',
      'longitude',
      'exact_location',
      'street_address',
      'free_text',
      'tracker_location',
    ]) {
      expect(lower, isNot(contains(forbidden)));
    }
  });

  test('both hubs expose and test the theft action', () {
    final financialResponsive = _read(
      'test/financial_tools_responsive_test.dart',
    );
    final actionResponsive = _read('test/action_center_responsive_test.dart');

    expect(financialResponsive, contains("'/theft-assistant'"));
    expect(financialResponsive, contains("'Réagir à un vol'"));
    expect(financialResponsive, contains('find.text(label)'));
    expect(financialResponsive, contains('tester.scrollUntilVisible'));
    expect(financialResponsive, contains('scrollable: scrollable'));
    expect(financialResponsive, contains("'Réviser mon assurance'"));

    expect(actionResponsive, contains("'/theft-assistant'"));
    expect(actionResponsive, contains("'Réagir à un vol'"));
    expect(actionResponsive, contains('find.text(label)'));
    expect(actionResponsive, contains('tester.scrollUntilVisible'));
    expect(actionResponsive, contains('scrollable: scrollable'));
  });

  test('lot 12 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/theft_assistant/theft_assistant_models.dart',
      'lib/features/theft_assistant/theft_assistant_calculator.dart',
      'lib/features/theft_assistant/theft_assistant_service.dart',
      'lib/features/theft_assistant/theft_assistant_page.dart',
    ]) {
      final source = _read(path);
      expect(RegExp(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(source), isFalse);
      expect(source, isNot(contains('@override\n  @override')));
      expect(source, isNot(contains('ScaffoldMessenger.of(this.context)')));
      expect(source, isNot(contains('final TheftAssistantProfile context;')));
      expect(RegExp(r'\brequired\s+this\.context\b').hasMatch(source), isFalse);
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
