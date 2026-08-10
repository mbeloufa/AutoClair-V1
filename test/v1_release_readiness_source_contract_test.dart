import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 commercial building blocks from lots 8 to 11 are present', () {
    const expected = <String>[
      'lib/features/vehicle_insights/vehicle_360_access.dart',
      'lib/features/vehicle_insights/vehicle_360_access_card.dart',
      'supabase/functions/claim-vehicle-360-trial/index.ts',
      'lib/features/vehicle_care/vehicle_assistant_brief.dart',
      'lib/features/vehicle_care/vehicle_assistant_brief_card.dart',
      'lib/features/vehicle_care/vehicle_smart_reminder.dart',
      'lib/features/vehicle_care/vehicle_smart_reminder_store.dart',
      'lib/core/widgets/app_state_panel.dart',
    ];

    for (final path in expected) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'Missing V1 building block: $path',
      );
    }
  });

  test('Bilan 360 freemium keeps the real credit ledger contract', () {
    final report = File(
      'supabase/functions/generate-vehicle-360-report/index.ts',
    ).readAsStringSync();
    final trial = File(
      'supabase/functions/claim-vehicle-360-trial/index.ts',
    ).readAsStringSync();

    expect(report, contains('const billingMode = "credits";'));
    expect(report, isNot(contains('AUTOCLAIR_BILLING_MODE')));
    expect(trial, contains('vehicle_report_credit_events'));
    expect(trial, contains('trial:vehicle_360:'));
    expect(trial, contains('auth.getUser(token)'));
  });

  test('vehicle assistant and reminders stay deliberately limited', () {
    final assistant = File(
      'lib/features/vehicle_care/vehicle_assistant_brief.dart',
    ).readAsStringSync();
    final reminders = File(
      'lib/features/vehicle_care/vehicle_smart_reminder.dart',
    ).readAsStringSync();

    expect(assistant, contains('.take(3)'));
    expect(assistant, contains('recall.isPlausibleFor(vehicle.model)'));
    expect(reminders, contains('const int maxVehicleSmartReminders = 3;'));
    expect(
      reminders,
      contains('if (result.length == maxVehicleSmartReminders) break;'),
    );
  });

  test('commercial UX uses reusable user-facing states', () {
    final statePanel = File(
      'lib/core/widgets/app_state_panel.dart',
    ).readAsStringSync();
    final vehicles = File(
      'lib/features/home/vehicles_page.dart',
    ).readAsStringSync();
    final history = File(
      'lib/features/home/history_page.dart',
    ).readAsStringSync();

    expect(statePanel, contains('class AppStatePanel'));
    expect(statePanel, contains('liveRegion: loading'));
    expect(vehicles, contains('AppStatePanel'));
    expect(history, contains('AppStatePanel'));
    expect(vehicles, isNot(contains('Text(_errorMessage!')));
    expect(history, isNot(contains('Text(_errorMessage!')));
  });

  test('registration provider secret never belongs in Flutter client', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      expect(
        source,
        isNot(contains('API_PLAQUE_IMMATRICULATION_TOKEN')),
        reason: 'Provider secret name found in Flutter client: ${entity.path}',
      );
    }
  });

  test('V1 source does not regress to the obsolete package name', () {
    final roots = <Directory>[Directory('lib'), Directory('test')];
    final obsoletePackageImport = <String>[
      'package:autoclair_',
      'flutter_auth_v1/',
    ].join();

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        expect(
          source,
          isNot(contains(obsoletePackageImport)),
          reason: 'Obsolete package import in ${entity.path}',
        );
      }
    }
  });
}
