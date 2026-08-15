import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('maintenance V14 exposes visual carnet and reminder controls', () {
    final page = read('lib/features/vehicle_care/vehicle_care_page.dart');
    final section = read(
      'lib/features/vehicle_care/maintenance_v14_section.dart',
    );
    final service = read(
      'lib/features/vehicle_care/maintenance_v14_service.dart',
    );
    final migration = read(
      'supabase/migrations/20260815203000_maintenance_carnet_v14.sql',
    );

    expect(page, contains("import 'maintenance_v14_section.dart';"));
    expect(page, contains('MaintenanceV14Section('));
    expect(page, contains('Offstage('));
    expect(page, contains('VehicleSmartReminderCard('));

    for (final marker in [
      'Carnet d’entretien',
      'À faire',
      'Historique',
      'Rappels',
      'Tous les rappels d’entretien',
      'Check-up rapide',
      'Tester la climatisation',
      'Contrôler les essuie-glaces',
      'Filtre d’habitacle',
      'Marquer comme fait',
      'Pourquoi cette date ?',
      'routine:quick-check',
      'seasonal:climate',
      'seasonal:wipers',
      'maintenance-v14-master-switch',
    ]) {
      expect(section, contains(marker));
    }

    expect(section, contains('synchronizeEssentialReminders'));
    expect(section, contains('cancelEssentialReminders'));
    expect(service, contains('vehicle_maintenance_reminder_preferences'));
    expect(service, contains('reminders_enabled'));

    expect(migration, contains('vehicle_maintenance_reminder_preferences'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('reminders_enabled boolean'));
    expect(migration, contains('autoclair_user_owns_vehicle'));
  });
}
