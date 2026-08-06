import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 13 exposes the risk forecast from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final home = _read('lib/features/home/home_page.dart');

    expect(
      router,
      contains(
        "import '../../features/risk_forecast/risk_forecast_page.dart';",
      ),
    );
    expect(router, contains("path: '/risk-forecast'"));
    expect(router, contains('const RiskForecastPage()'));

    for (final source in [center, hub]) {
      expect(source, contains("title: 'Anticiper les risques'"));
      expect(source, contains("route: '/risk-forecast'"));
    }
    expect(center, contains(r"ValueKey('action-tool-${tool.route}')"));
    expect(home, contains("'Ouvrir les 16 outils'"));
    for (final label in ['vol', 'départ', 'inspection', 'risques', 'achat']) {
      expect(home, contains(label));
    }
  });

  test('lot 13 remains explainable and never claims a diagnosis', () {
    final calculator = _read(
      'lib/features/risk_forecast/risk_forecast_calculator.dart',
    );
    final models = _read(
      'lib/features/risk_forecast/risk_forecast_models.dart',
    );
    final page = _read('lib/features/risk_forecast/risk_forecast_page.dart');

    for (final requiredValue in [
      'BRAKING_SIGNAL',
      'ENGINE_COOLING_SIGNAL',
      'MAINTENANCE_GAP',
      'REPEATED_BREAKDOWNS',
      'hasSafetyCritical || score >= 70',
      'RiskForecastConfidence.strong',
    ]) {
      expect(calculator, contains(requiredValue));
    }

    expect(models, contains('ni un diagnostic mécanique'));
    expect(models, contains('ni une garantie de panne'));
    expect(page, contains('jamais un diagnostic mécanique'));
    expect(page, contains("ValueKey('risk-forecast-result')"));
    expect(page, contains("context.push<void>('/maintenance-planner')"));
    expect(page, isNot(contains('panne certaine')));
    expect(page, isNot(contains('garantie sans panne')));
  });

  test('lot 13 stores only a minimal protected assessment', () {
    final service = _read(
      'lib/features/risk_forecast/risk_forecast_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806100000_vehicle_risk_forecast_v1.sql',
    );

    expect(service, contains('VehicleService'));
    expect(service, contains("from('vehicle_risk_profiles')"));
    expect(service, contains("from('vehicle_risk_assessments')"));
    expect(service, contains("'calculator_version': 'risk-forecast-v1'"));

    for (final forbiddenValue in [
      'functions.invoke',
      'recordCost(',
      'recordOpportunity(',
      'recordEvent(',
      'latitude',
      'longitude',
      'trip_path',
    ]) {
      expect(service, isNot(contains(forbiddenValue)));
    }

    for (final requiredValue in [
      'vehicle_risk_profiles',
      'vehicle_risk_assessments',
      'enable row level security',
      'user_id = auth.uid()',
      'public.autoclair_user_owns_vehicle(vehicle_id)',
    ]) {
      expect(migration, contains(requiredValue));
    }
    expect(
      RegExp(
        r'^\s*create\s+policy\s+',
        multiLine: true,
      ).allMatches(migration).length,
      7,
    );

    for (final forbiddenValue in [
      'vin',
      'latitude',
      'longitude',
      'exact_location',
      'street_address',
      'free_text',
      'trip_path',
      'audio_recording',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbiddenValue)));
    }
  });

  test('lot 13 cumulative navigation exposes and tests the risk action', () {
    final centerTest = _read('test/action_center_responsive_test.dart');
    final financialTest = _read('test/financial_tools_responsive_test.dart');
    final navigationContract = _read('test/lot11_5_source_contract_test.dart');
    final theftContract = _read('test/lot12_source_contract_test.dart');

    expect(centerTest, contains('Lot 4 to Lot 15'));
    expect(centerTest, contains("action-tool-/risk-forecast"));
    expect(centerTest, contains('Analyse des risques ouverte'));
    expect(centerTest, contains("ValueKey('action-center-scroll')"));
    expect(centerTest, contains('tester.scrollUntilVisible'));
    expect(centerTest, contains('scrollable: scrollable'));
    expect(financialTest, contains("'/risk-forecast'"));
    expect(financialTest, contains("'Anticiper les risques'"));
    expect(financialTest, contains("'Inspecter mon véhicule'"));
    expect(financialTest, contains("'Préparer mon départ'"));
    expect(financialTest, contains('find.text(label)'));
    expect(financialTest, contains('tester.scrollUntilVisible'));
    expect(navigationContract, contains('every Lot 4 to Lot 15 module'));
    expect(navigationContract, contains('allMatches(center).length, 16'));
    expect(theftContract, contains("'Tous les outils AutoClair'"));
    expect(theftContract, contains("'Réagir à un vol'"));
    expect(theftContract, contains('find.text(label)'));
    expect(theftContract, isNot(contains('Ouvrir les 13 outils')));
  });

  test('lot 13 dart sources avoid known regressions', () {
    final sources = <String>[
      'lib/core/router/app_router.dart',
      'lib/features/home/home_page.dart',
      'lib/features/home/action_center_page.dart',
      'lib/features/financial_tools/financial_tools_page.dart',
      'lib/features/risk_forecast/risk_forecast_models.dart',
      'lib/features/risk_forecast/risk_forecast_calculator.dart',
      'lib/features/risk_forecast/risk_forecast_service.dart',
      'lib/features/risk_forecast/risk_forecast_page.dart',
    ].map(_read).toList(growable: false);

    for (final source in sources) {
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
