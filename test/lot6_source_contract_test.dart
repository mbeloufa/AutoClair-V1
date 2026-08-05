import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('lot 6 exposes a foreground-only eco-driving coach', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final page = _read('lib/features/eco_driving/eco_driving_page.dart');
    final tracker = _read('lib/features/eco_driving/eco_driving_tracker.dart');
    final service = _read('lib/features/eco_driving/eco_driving_service.dart');

    expect(router, contains("path: '/eco-driving'"));
    expect(hub, contains("title: 'Améliorer ma conduite'"));
    expect(hub, contains("route: '/eco-driving'"));
    expect(page, contains('Votre trajet reste privé'));
    expect(page, contains('Aucun point GPS'));
    expect(page, contains('AppLifecycleState.resumed'));
    expect(tracker, contains('Geolocator.getPositionStream'));
    expect(tracker, contains('distanceFilter: 10'));
    expect(tracker, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(service, contains("featureCode: 'ECO_DRIVING_COACH'"));
    expect(service, contains('status: SavingStatus.detected'));
  });

  test('lot 6 migration stores aggregates without route coordinates', () {
    final migration = _read(
      'supabase/migrations/20260805210500_eco_driving_v1.sql',
    );

    for (final expected in [
      'begin;',
      'commit;',
      'vehicle_eco_driving_profiles',
      'eco_driving_sessions',
      'enable row level security',
      'user_id = auth.uid()',
      'public.autoclair_user_owns_vehicle(vehicle_id)',
      'potential_saving <= baseline_energy_cost',
      'moving_seconds + idle_seconds <= duration_seconds + 60',
    ]) {
      expect(migration, contains(expected));
    }

    expect(migration, isNot(contains('latitude')));
    expect(migration, isNot(contains('longitude')));
    expect(migration, isNot(contains('route_points')));
  });

  test('financial hub scrolls to the eco-driving card', () {
    final responsive = _read('test/financial_tools_responsive_test.dart');

    expect(responsive, contains("'/eco-driving'"));
    expect(responsive, contains("find.text('Améliorer ma conduite')"));
    expect(responsive, contains('tester.scrollUntilVisible'));
    expect(responsive, contains('scrollable: scrollable'));
  });

  test('duration formatter keeps simple interpolation lint-clean', () {
    final page = _read('lib/features/eco_driving/eco_driving_page.dart');

    expect(page, isNot(contains(r'${hours} h')));
    expect(
      page,
      contains(r"$hours h ${minutes.toString().padLeft(2, '0')} min"),
    );
  });
}
