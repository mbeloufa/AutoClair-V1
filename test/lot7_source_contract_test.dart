import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('lot 7 exposes maintenance planning from the financial hub', () {
    final router = _read('lib/core/router/app_router.dart');
    final hub = _read('lib/features/financial_tools/financial_tools_page.dart');
    final page = _read(
      'lib/features/maintenance_planner/maintenance_planner_page.dart',
    );

    expect(router, contains("path: '/maintenance-planner'"));
    expect(hub, contains("title: 'Planifier mon entretien'"));
    expect(hub, contains("route: '/maintenance-planner'"));
    expect(page, contains('Budget prévisionnel sur 12 mois'));
    expect(page, contains('Planifier dans le carnet'));
    expect(page, contains('AutoClair ne réalise pas de diagnostic mécanique'));
  });

  test('lot 7 reuses the vehicle log and never books a real expense', () {
    final service = _read(
      'lib/features/maintenance_planner/maintenance_planner_service.dart',
    );

    expect(service, contains('_careService.recordEvent'));
    expect(service, contains("status: 'PLANNED'"));
    expect(service, contains('reminderEnabled: true'));
    expect(service, contains('_effectiveReminderDays'));
    expect(service, contains('supportedVehicleEventReminderDays'));
    expect(service, isNot(contains('recordCost(')));
    expect(service, isNot(contains('recordOpportunity(')));
  });

  test('lot 7 migration protects the usage profile with RLS', () {
    final migration = _read(
      'supabase/migrations/20260805213000_maintenance_planner_v1.sql',
    );

    expect(
      migration,
      contains(
        'create table if not exists public.vehicle_maintenance_planner_profiles',
      ),
    );
    expect(migration, contains('enable row level security'));
    expect(migration, contains('user_id = auth.uid()'));
    expect(
      migration,
      contains('public.autoclair_user_owns_vehicle(vehicle_id)'),
    );
    expect(migration, contains('reminder_days_before in (1, 3, 7, 14, 30)'));
  });

  test('financial hub scrolls to the maintenance planner card', () {
    final responsiveTest = _read('test/financial_tools_responsive_test.dart');

    expect(responsiveTest, contains("'/maintenance-planner'"));
    expect(responsiveTest, contains("find.text(label)"));
    expect(responsiveTest, contains('tester.scrollUntilVisible'));
  });

  test('lot 7 page remains lint-clean and keeps unique form controls', () {
    final page = _read(
      'lib/features/maintenance_planner/maintenance_planner_page.dart',
    );

    expect(RegExp(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}').hasMatch(page), isFalse);
    expect(
      RegExp(r'DropdownButtonFormField<String>\(').allMatches(page).length,
      1,
    );
    expect(
      RegExp(r'DropdownButtonFormField<int>\(').allMatches(page).length,
      1,
    );
    expect(RegExp(r'@override\s+@override').hasMatch(page), isFalse);
  });

  test('lot 7 uses calendar dates instead of fixed 24-hour durations', () {
    final calculator = _read(
      'lib/features/maintenance_planner/maintenance_planner_calculator.dart',
    );
    final calculatorTest = _read(
      'test/maintenance_planner_calculator_test.dart',
    );

    expect(calculator, contains('_addCalendarDays'));
    expect(calculator, contains('_calendarDayDifference'));
    expect(calculator, contains('DateTime.utc('));
    expect(
      calculator,
      isNot(contains('return now.add(Duration(days: days));')),
    );
    expect(calculator, isNot(contains('.difference(now).inDays')));
    expect(calculatorTest, contains('across spring DST'));
    expect(calculatorTest, contains('DateTime(2027, 4, 2)'));
  });
}
