import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lot 10 exposes used-purchase verification from the financial hub', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final page = _read('lib/features/used_purchase/used_purchase_page.dart');

    expect(router, contains("path: '/used-purchase'"));
    expect(router, contains('const UsedPurchasePage()'));
    expect(hub, contains("title: 'Sécuriser mon achat'"));
    expect(hub, contains("route: '/used-purchase'"));
    expect(page, contains('Analyser cet achat'));
    expect(page, contains('Il ne remplace pas une expertise mécanique'));
  });

  test(
    'lot 10 applies official document validity rules with calendar dates',
    () {
      final calculator = _read(
        'lib/features/used_purchase/used_purchase_calculator.dart',
      );
      final test = _read('test/used_purchase_calculator_test.dart');

      expect(calculator, contains('_addCalendarDays'));
      expect(calculator, contains('_addCalendarMonths'));
      expect(calculator, contains('_addCalendarDays(csaDate, 14)'));
      expect(calculator, contains('validityMonths'));
      expect(calculator, contains('DateTime.utc('));
      expect(test, contains('control issued on month end'));
      expect(test, contains('DateTime(2026, 7, 31)'));
    },
  );

  test(
    'lot 10 stores no seller identity or location and protects data with RLS',
    () {
      final migration = _read(
        'supabase/migrations/20260805232000_used_purchase_assistant_v1.sql',
      );
      final lower = migration.toLowerCase();

      expect(migration, contains('used_vehicle_purchase_profiles'));
      expect(migration, contains('used_vehicle_purchase_assessments'));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('user_id = auth.uid()'));
      expect(_count(migration, 'create policy'), 7);
      for (final forbidden in [
        'seller_name',
        'seller_phone',
        'seller_email',
        'seller_address',
        'latitude',
        'longitude',
        'conversation',
      ]) {
        expect(lower, isNot(contains(forbidden)));
      }
    },
  );

  test('lot 10 adds no valuation API and creates no automatic expense', () {
    final page = _read('lib/features/used_purchase/used_purchase_page.dart');
    final service = _read(
      'lib/features/used_purchase/used_purchase_service.dart',
    );
    final pubspec = _read('pubspec.yaml');

    expect(page, contains('Budget maximum tout compris'));
    expect(service, isNot(contains('recordCost(')));
    expect(service, isNot(contains('recordOpportunity(')));
    expect(service, isNot(contains('VehicleService')));
    expect(pubspec, isNot(contains('vehicle_valuation')));
  });

  test('financial hub scrolls to the off-screen used-purchase card', () {
    final responsive = _read('test/financial_tools_responsive_test.dart');

    expect(responsive, contains("'/used-purchase'"));
    expect(responsive, contains("find.text('Sécuriser mon achat')"));
    expect(responsive, contains('tester.scrollUntilVisible'));
    expect(responsive, contains('scrollable: scrollable'));
  });

  test('lot 10 dart sources avoid known regressions', () {
    final files = [
      'lib/features/used_purchase/used_purchase_models.dart',
      'lib/features/used_purchase/used_purchase_calculator.dart',
      'lib/features/used_purchase/used_purchase_service.dart',
      'lib/features/used_purchase/used_purchase_page.dart',
    ];

    for (final path in files) {
      final source = _read(path);
      expect(RegExp(r'\$\{[A-Za-z_]\w*\}').hasMatch(source), isFalse);
      expect(RegExp(r'@override\s+@override').hasMatch(source), isFalse);
      expect(source, isNot(contains('ScaffoldMessenger.of(this.context)')));
    }
  });
}

String _read(String relativePath) {
  return File(relativePath).readAsStringSync();
}

int _count(String source, String pattern) {
  return pattern.allMatches(source.toLowerCase()).length;
}
