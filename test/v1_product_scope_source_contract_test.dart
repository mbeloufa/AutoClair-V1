import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public commercial V1 contains only approved product journeys', () {
    final center = File(
      'lib/features/home/action_center_page.dart',
    ).readAsStringSync();
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final catalog = File(
      'lib/features/documents/document_type_catalog.dart',
    ).readAsStringSync();

    for (final label in [
      'Mon véhicule & carnet',
      'Analyser un document',
      'Services autour de moi',
      'Acheter un véhicule',
      'Vendre mon véhicule',
      'Offres automobiles',
    ]) {
      expect(center, contains(label));
    }

    expect(RegExp(r"route: '/[^']+'").allMatches(center).length, 6);

    const excludedRoutes = <String>[
      '/accident-assistant',
      '/battery-care',
      '/body-safety-care',
      '/brake-care',
      '/breakdown-assistant',
      '/budget',
      '/charging-optimizer',
      '/compliance',
      '/eco-driving',
      '/fluid-care',
      '/fuel-optimizer',
      '/insurance-review',
      '/lease-return',
      '/maintenance-planner',
      '/quote-comparison',
      '/risk-forecast',
      '/technical-control-readiness',
      '/theft-assistant',
      '/tire-care',
      '/trip-readiness',
      '/vehicle-inspection',
      '/vehicle-storage',
      '/visibility-care',
      '/workshop-visit',
    ];

    for (final route in excludedRoutes) {
      expect(
        center,
        isNot(contains("route: '$route'")),
        reason: 'Legacy route must not be exposed in the V1 hub: $route',
      );
      expect(
        router,
        contains("path: '$route'"),
        reason:
            'Legacy route is intentionally retained only for redirect compatibility.',
      );
      final routePattern = RegExp(
        "path:\\s*'${RegExp.escape(route)}'[\\s\\S]*?redirect:\\s*"
        "\\(context, state\\)\\s*=>\\s*'/actions'",
      );
      expect(
        routePattern.hasMatch(router),
        isTrue,
        reason: 'Legacy route must redirect to the V1 hub: $route',
      );
    }

    expect(catalog, contains("value: 'loa_contract'"));
    expect(catalog, contains("value: 'lld_contract'"));
    expect(catalog, contains("value: 'insurance_contract'"));
  });
}
