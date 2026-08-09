import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('lot 5 exposes a cost-aware charging optimizer', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final page = _read(
      'lib/features/charging_optimizer/charging_optimizer_page.dart',
    );
    final service = _read(
      'lib/features/charging_optimizer/charging_optimizer_service.dart',
    );

    expect(router, contains("path: '/charging-optimizer'"));
    expect(hub, contains("title: 'Optimiser ma recharge'"));
    expect(hub, contains("route: '/charging-optimizer'"));
    expect(page, contains('Coût complet estimé'));
    expect(page, contains('Tarif habituel de référence'));
    expect(page, isNot(contains('tester.scrollUntilVisible')));
    expect(
      service,
      contains("import '../charging_prices/charging_station_offer.dart';"),
    );
    expect(service, contains("category: 'CHARGING'"));
    expect(service, contains("featureCode: 'CHARGING_OPTIMIZER'"));
  });

  test('lot 5 migration protects the charging profile', () {
    final migration = _read(
      'supabase/migrations/20260805204500_charging_optimizer_v1.sql',
    );

    for (final expected in [
      'begin;',
      'commit;',
      'vehicle_charging_profiles',
      'enable row level security',
      'user_id = auth.uid()',
      'public.autoclair_user_owns_vehicle(vehicle_id)',
      'reference_price_per_kwh >= 0',
      'max_charging_power_kw <= 500',
    ]) {
      expect(migration, contains(expected));
    }
  });

  test('financial hub scrolls to the new off-screen card', () {
    final responsive = _read('test/financial_tools_responsive_test.dart');

    expect(responsive, contains("'/charging-optimizer'"));
    expect(responsive, contains("'Optimiser ma recharge'"));
    expect(responsive, contains('tester.scrollUntilVisible'));
    expect(responsive, contains('scrollable: scrollable'));
  });
}
