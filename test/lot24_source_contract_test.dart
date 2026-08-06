import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 24 exposes body safety care from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );

    expect(
      router,
      contains(
        "import '../../features/body_safety_care/body_safety_care_page.dart';",
      ),
    );
    expect(router, contains("path: '/body-safety-care'"));
    expect(router, contains('const BodySafetyCarePage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Vérifier carrosserie et sécurité'"));
      expect(source, contains("route: '/body-safety-care'"));
    }
  });

  test('lot 24 remains declarative and never claims structural expertise', () {
    final models = _read(
      'lib/features/body_safety_care/body_safety_care_models.dart',
    );
    final calculator = _read(
      'lib/features/body_safety_care/body_safety_care_calculator.dart',
    );
    final page = _read(
      'lib/features/body_safety_care/body_safety_care_page.dart',
    );

    final normalizedModels = models.replaceAll(RegExp(r"'\s*'"), '');
    expect(normalizedModels, contains('expertise structurelle'));
    expect(normalizedModels, contains('certification de conformité'));
    expect(calculator, contains('completeness < 100 || score < 88'));
    for (final forbidden in [
      'redresser une pièce',
      'certifie conforme',
      'réparation garantie',
    ]) {
      expect(page.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 24 stores only a protected structured body safety check', () {
    final migration = _read(
      'supabase/migrations/20260806153000_body_safety_care_v1.sql',
    );
    expect(
      migration,
      contains('create table if not exists public.body_safety_checks'),
    );
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains('public.autoclair_user_owns_vehicle(vehicle_id)'),
    );
    expect(
      RegExp(r'^create policy ', multiLine: true).allMatches(migration).length,
      3,
    );
    for (final forbidden in [
      'plate_number',
      'occupant_name',
      'part_number',
      'measurement',
      'latitude',
      'longitude',
      'address',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(migration.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 24 cumulative navigation exposes and tests body safety care', () {
    final home = _read('lib/features/home/home_page.dart');
    final navigation = _read('test/lot11_5_source_contract_test.dart');
    final responsive = _read('test/action_center_responsive_test.dart');

    expect(home, contains("'Ouvrir les 25 outils'"));
    expect(
      navigation,
      contains("'Vérifier carrosserie et sécurité': '/body-safety-care'"),
    );
    expect(navigation, contains('Lot 4 to Lot 24'));
    expect(
      responsive,
      contains("'body safety care action opens its direct route'"),
    );
  });

  test('lot 24 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/body_safety_care/body_safety_care_calculator.dart',
      'lib/features/body_safety_care/body_safety_care_models.dart',
      'lib/features/body_safety_care/body_safety_care_page.dart',
      'lib/features/body_safety_care/body_safety_care_service.dart',
    ]) {
      final source = _read(path);
      expect(source, isNot(contains('visitContext: context')));
      expect(source, isNot(contains('Duration(hours: 24)')));
      expect(source, isNot(contains('ScaffoldMessenger.of(this.context)')));
    }
  });
}

String _read(String relativePath) => File(relativePath).readAsStringSync();
