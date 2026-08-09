import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('lot 9 exposes sale preparation from the financial hub', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final page = _read(
      'lib/features/sale_preparation/sale_preparation_page.dart',
    );

    expect(router, contains("path: '/sale-preparation'"));
    expect(router, contains('const SalePreparationPage()'));
    expect(hub, contains("title: 'Préparer ma vente'"));
    expect(hub, contains("route: '/sale-preparation'"));
    expect(page, contains('Ouvrir HistoVec'));
    expect(page, contains('Découvrir Simplimmat'));
    expect(page, contains('Ouvrir France Titres'));
  });

  test('lot 9 applies the official French sale timing rules', () {
    final models = _read(
      'lib/features/sale_preparation/sale_preparation_models.dart',
    );
    final calculator = _read(
      'lib/features/sale_preparation/sale_preparation_calculator.dart',
    );

    expect(models, contains('SaleBuyerType.automotiveProfessional'));
    expect(calculator, contains('_addCalendarMonths'));
    expect(calculator, contains('_addCalendarDays'));
    expect(calculator, contains('validityMonths'));
    expect(
      calculator,
      contains('status == SaleTechnicalControlStatus.majorDefects'),
    );
    expect(
      calculator,
      contains('csaExpiresAt = _addCalendarDays(csaDate, 14)'),
    );
    expect(
      calculator,
      contains('profile.buyerType == SaleBuyerType.privateIndividual'),
    );
    expect(calculator, contains('if (!privateSale)'));
    expect(calculator, contains('défaillance critique'));
  });

  test('lot 9 stores no buyer identity and protects data with RLS', () {
    final migration = _read(
      'supabase/migrations/20260805223000_sale_preparation_v1.sql',
    ).toLowerCase();

    expect(migration, contains('vehicle_sale_preparation_profiles'));
    expect(migration, contains('vehicle_sale_readiness_snapshots'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('user_id = auth.uid()'));
    expect(migration, contains('autoclair_user_owns_vehicle(vehicle_id)'));
    expect(RegExp(r'\bcreate\s+policy\b').allMatches(migration).length, 7);
    for (final forbidden in [
      'buyer_name',
      'buyer_phone',
      'buyer_email',
      'buyer_address',
      'latitude',
      'longitude',
    ]) {
      expect(migration, isNot(contains(forbidden)));
    }
  });

  test('lot 9 adds no valuation API and does not claim a guaranteed price', () {
    final page = _read(
      'lib/features/sale_preparation/sale_preparation_page.dart',
    );
    final service = _read(
      'lib/features/sale_preparation/sale_preparation_service.dart',
    );
    final models = _read(
      'lib/features/sale_preparation/sale_preparation_models.dart',
    );

    expect(page, contains('Il ne fixe pas la valeur de marché'));
    expect(service, isNot(contains('functions.invoke')));
    expect(service, isNot(contains('recordCost(')));
    expect(service, isNot(contains('recordOpportunity(')));
    expect(models, contains('Il ne remplace pas les '));
    expect(models, contains('démarches officielles ni un conseil juridique'));
  });

  test('financial hub scrolls to the off-screen sale preparation card', () {
    final responsiveTest = _read('test/financial_tools_responsive_test.dart');

    expect(responsiveTest, contains("'/sale-preparation'"));
    expect(responsiveTest, contains("'Préparer ma vente'"));
    expect(responsiveTest, contains('tester.scrollUntilVisible'));
    expect(responsiveTest, contains('scrollable: scrollable'));
  });

  test('lot 9 dart sources avoid known regressions', () {
    final paths = [
      'lib/features/sale_preparation/sale_preparation_models.dart',
      'lib/features/sale_preparation/sale_preparation_calculator.dart',
      'lib/features/sale_preparation/sale_preparation_service.dart',
      'lib/features/sale_preparation/sale_preparation_page.dart',
    ];

    for (final path in paths) {
      final source = _read(path);
      expect(
        RegExp(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(source),
        isFalse,
        reason: path,
      );
      expect(
        RegExp(r'@override\s+@override').hasMatch(source),
        isFalse,
        reason: path,
      );
    }
  });

  test('sale page keeps business context distinct from BuildContext', () {
    final page = _read(
      'lib/features/sale_preparation/sale_preparation_page.dart',
    );

    expect(page, contains('ScaffoldMessenger.of(context)'));
    expect(page, isNot(contains('ScaffoldMessenger.of(this.context)')));
    expect(page, contains('required this.saleContext'));
    expect(page, contains('final SalePreparationContext saleContext;'));
    expect(page, contains('saleContext.completedDocumentCount'));
    expect(page, contains('saleContext.recentConfirmedEventCount'));
    expect(page, contains('saleContext.saleReadinessScore'));
    expect(page, isNot(contains('final SalePreparationContext context;')));
    expect(page, isNot(contains('required this.context')));
  });
}
