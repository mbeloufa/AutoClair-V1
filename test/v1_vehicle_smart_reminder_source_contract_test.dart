import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'V1 adds opt-in essential reminders without replacing event reminders',
    () {
      final page = File(
        'lib/features/vehicle_care/vehicle_care_page.dart',
      ).readAsStringSync();
      final planner = File(
        'lib/features/vehicle_care/vehicle_smart_reminder.dart',
      ).readAsStringSync();
      final notifications = File(
        'lib/features/vehicle_care/vehicle_event_notification_service.dart',
      ).readAsStringSync();

      expect(page, contains('VehicleSmartReminderCard'));
      expect(page, contains('VehicleSmartReminderStore'));
      expect(page, contains('ensurePermission()'));
      expect(page, contains('cancelEssentialReminders'));
      expect(page, contains('_synchronizeEventReminders(vehicle)'));

      expect(planner, contains('maxVehicleSmartReminders = 3'));
      expect(planner, contains("source.contains('RECALL')"));
      expect(planner, contains("source.contains('EVENT')"));
      expect(planner, contains('dueDate == null'));

      expect(notifications, contains('autoclair_vehicle_moments'));
      expect(notifications, contains('vehicleSmartNotificationPayloadPrefix'));
      expect(notifications, contains('synchronizeReminders'));
      expect(notifications, contains('synchronizeEssentialReminders'));
    },
  );

  test('essential reminders stay local and add no backend or API cost', () {
    final planner = File(
      'lib/features/vehicle_care/vehicle_smart_reminder.dart',
    ).readAsStringSync();
    final store = File(
      'lib/features/vehicle_care/vehicle_smart_reminder_store.dart',
    ).readAsStringSync();

    for (final source in [planner, store]) {
      expect(source, isNot(contains('Supabase.instance')));
      expect(source, isNot(contains('functions.invoke')));
      expect(source, isNot(contains('http://')));
      expect(source, isNot(contains('https://')));
    }

    expect(store, contains('SharedPreferencesAsync'));
  });
}
