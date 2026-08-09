import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  test('financial hub exposes the five priority features', () {
    final router = _read('lib/core/router/app_router.dart');
    final home = _read('lib/features/home/home_page.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');

    for (final route in [
      "path: '/budget'",
      "path: '/fuel-optimizer'",
      "path: '/compliance'",
      "path: '/quote-comparison'",
      "path: '/insurance-review'",
    ]) {
      expect(router, contains(route));
    }
    expect(home, contains("title: 'Mes économies'"));
    expect(hub, contains('Mon budget automobile'));
    expect(hub, contains('Optimiser mon plein'));
    expect(hub, contains('Comparer mes devis'));
    expect(hub, contains('Réviser mon assurance'));
  });

  test('financial migration protects ownership and confirmed savings', () {
    final sql = _read(
      'supabase/migrations/20260805170000_financial_copilot_v1.sql',
    );
    expect(sql, contains('enable row level security'));
    expect(sql, contains('public.autoclair_user_owns_vehicle(vehicle_id)'));
    expect(sql, contains("status <> 'CONFIRMED' or confirmed_at is not null"));
    expect(sql, contains('potential_saving > 0'));
    expect(sql, contains('contract_number_masked'));
  });

  test(
    'financial pages remain compatible with Lot 3 widgets and null safety',
    () {
      final fuelPage = _read(
        'lib/features/fuel_optimizer/fuel_optimizer_page.dart',
      );
      final insurancePage = _compact(
        _read('lib/features/insurance_review/insurance_review_page.dart'),
      );
      final budgetPage = _read(
        'lib/features/vehicle_budget/vehicle_budget_page.dart',
      );

      expect(
        fuelPage,
        isNot(contains("import '../fuel_prices/fuel_station_offer.dart';")),
      );
      expect(fuelPage, contains("title: 'Rayon maximal'"));
      expect(fuelPage, isNot(contains("label: 'Rayon maximal'")));

      expect(
        insurancePage,
        contains(
          'review.current.annualPremium < review.previous.annualPremium',
        ),
      );
      expect(
        insurancePage,
        isNot(contains('current.annualPremium < previous.annualPremium')),
      );
      expect(
        insurancePage,
        contains('final DateTime _snapshotDate = DateTime.now();'),
      );
      expect(budgetPage, contains('final DateTime _date = DateTime.now();'));
    },
  );

  test('responsive hub test scrolls to off-screen financial cards', () {
    final responsiveTest = _read('test/financial_tools_responsive_test.dart');

    expect(responsiveTest, contains('tester.scrollUntilVisible'));
    expect(responsiveTest, contains("'Optimiser mon plein'"));
    expect(responsiveTest, contains("'Réviser mon assurance'"));
    expect(responsiveTest, contains('scrollable: scrollable'));
  });
}
