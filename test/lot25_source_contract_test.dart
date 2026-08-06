import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 25 exposes lease return preparation from both navigation hubs', () {
    final router = _read('lib/core/router/app_router.dart');
    final center = _read('lib/features/home/action_center_page.dart');
    final financial = _read(
      'lib/features/financial_tools/financial_tools_page.dart',
    );

    expect(
      router,
      contains("import '../../features/lease_return/lease_return_page.dart';"),
    );
    expect(router, contains("path: '/lease-return'"));
    expect(router, contains('const LeaseReturnPage()'));
    for (final source in [center, financial]) {
      expect(source, contains("title: 'Préparer ma restitution'"));
      expect(source, contains("route: '/lease-return'"));
    }
  });

  test('lot 25 remains declarative and does not calculate return fees', () {
    final models = _read('lib/features/lease_return/lease_return_models.dart');
    final calculator = _read(
      'lib/features/lease_return/lease_return_calculator.dart',
    );
    final page = _read('lib/features/lease_return/lease_return_page.dart');

    final normalizedModels = models.replaceAll(RegExp(r"'\s*'"), '');
    expect(normalizedModels, contains('ne calcule aucun frais de restitution'));
    expect(normalizedModels, contains('n’interprète pas le contrat'));
    expect(calculator, contains('completeness < 100 || score < 88'));
    expect(page, contains("ValueKey('lease-return-evaluate')"));
    for (final forbidden in [
      'montant estimé',
      'frais prévus',
      'valeur de rachat calculée',
      'garantie sans frais',
      'conseil juridique',
    ]) {
      expect(page.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('lot 25 stores only a protected structured preparation', () {
    final service = _read(
      'lib/features/lease_return/lease_return_service.dart',
    );
    final migration = _read(
      'supabase/migrations/20260806154500_lease_return_v1.sql',
    );

    expect(service, contains("from('lease_return_preparations')"));
    expect(service, contains("'lease-return-v1'"));
    expect(migration, contains('lease_return_preparations'));
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains('public.autoclair_user_owns_vehicle(vehicle_id)'),
    );
    expect(
      RegExp(r'^create policy ', multiLine: true).allMatches(migration).length,
      3,
    );
    final identifiers = RegExp(r'[a-z0-9_]+')
        .allMatches(migration.toLowerCase())
        .map((match) => match.group(0))
        .whereType<String>()
        .toSet();
    for (final forbidden in [
      'contract_number',
      'lessor_name',
      'exact_amount',
      'buyout_amount',
      'latitude',
      'longitude',
      'address',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(identifiers, isNot(contains(forbidden)));
    }
  });

  test('lot 25 cumulative navigation exposes and tests lease return', () {
    final home = _read('lib/features/home/home_page.dart');
    final navigation = _read('test/lot11_5_source_contract_test.dart');
    final responsive = _read('test/action_center_responsive_test.dart');

    expect(home, contains("'Ouvrir les 26 outils'"));
    expect(navigation, contains("'Préparer ma restitution': '/lease-return'"));
    expect(navigation, contains('Lot 4 to Lot 25'));
    expect(
      responsive,
      contains("'lease return action opens its direct route'"),
    );
  });

  test('lot 25 dart sources avoid known regressions', () {
    for (final path in [
      'lib/features/lease_return/lease_return_calculator.dart',
      'lib/features/lease_return/lease_return_models.dart',
      'lib/features/lease_return/lease_return_page.dart',
      'lib/features/lease_return/lease_return_service.dart',
    ]) {
      final source = _read(path);
      expect(source, isNot(contains('Duration(hours: 24)')));
      expect(source, isNot(contains('functions.invoke')));
      expect(source, isNot(contains('ScaffoldMessenger.of(this.context)')));
    }
  });
}

String _read(String relativePath) => File(relativePath).readAsStringSync();
