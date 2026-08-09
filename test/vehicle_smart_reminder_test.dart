import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_smart_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('essential reminders keep only the three nearest dated moments', () {
    final now = DateTime(2026, 8, 9, 12);
    final plans = buildVehicleSmartReminderPlans(
      vehicleId: 'vehicle-1',
      now: now,
      schedules: [
        _schedule('a', 'Vidange', DateTime(2026, 9, 10)),
        _schedule('b', 'Contrôle technique', DateTime(2026, 10, 1)),
        _schedule('c', 'Liquide de frein', DateTime(2026, 11, 1)),
        _schedule('d', 'Filtre habitacle', DateTime(2026, 12, 1)),
      ],
      reminders: const [],
    );

    expect(plans, hasLength(3));
    expect(plans.map((plan) => plan.title), [
      'Vidange',
      'Contrôle technique',
      'Liquide de frein',
    ]);
  });

  test(
    'planned events and recalls are not duplicated by essential reminders',
    () {
      final plans = buildVehicleSmartReminderPlans(
        vehicleId: 'vehicle-1',
        now: DateTime(2026, 8, 9, 8),
        schedules: const [],
        reminders: [
          _reminder(
            'event',
            'Rendez-vous garage',
            DateTime(2026, 9, 1),
            sourceType: 'EVENT',
          ),
          _reminder(
            'recall',
            'Rappel constructeur',
            DateTime(2026, 9, 2),
            sourceType: 'RECALL',
          ),
          _reminder(
            'ct',
            'Contrôle technique',
            DateTime(2026, 9, 3),
            sourceType: 'COMPLIANCE',
          ),
        ],
      );

      expect(plans, hasLength(1));
      expect(plans.single.title, 'Contrôle technique');
    },
  );

  test(
    'same title is deduplicated between schedule and dashboard reminder',
    () {
      final plans = buildVehicleSmartReminderPlans(
        vehicleId: 'vehicle-1',
        now: DateTime(2026, 8, 9, 8),
        schedules: [
          _schedule('schedule-ct', 'Contrôle technique', DateTime(2026, 9, 20)),
        ],
        reminders: [
          _reminder(
            'reminder-ct',
            'Contrôle technique',
            DateTime(2026, 9, 20),
            sourceType: 'COMPLIANCE',
          ),
        ],
      );

      expect(plans, hasLength(1));
    },
  );

  test('reminder timing adapts without scheduling already due moments', () {
    final now = DateTime(2026, 8, 9, 8);

    expect(
      vehicleSmartReminderAt(dueAt: DateTime(2026, 9, 9), now: now),
      DateTime(2026, 8, 26, 9),
    );
    expect(
      vehicleSmartReminderAt(dueAt: DateTime(2026, 8, 18), now: now),
      DateTime(2026, 8, 15, 9),
    );
    expect(
      vehicleSmartReminderAt(dueAt: DateTime(2026, 8, 12), now: now),
      DateTime(2026, 8, 11, 9),
    );
    expect(
      vehicleSmartReminderAt(dueAt: DateTime(2026, 8, 10), now: now),
      isNull,
    );
  });

  test('notification ids and payloads stay scoped to the vehicle', () {
    final first = vehicleSmartNotificationId(
      vehicleId: 'vehicle-a',
      key: 'schedule-1',
    );
    final second = vehicleSmartNotificationId(
      vehicleId: 'vehicle-b',
      key: 'schedule-1',
    );

    expect(first, greaterThan(0));
    expect(second, greaterThan(0));
    expect(first, isNot(second));
    expect(
      vehicleSmartNotificationPayload(
        vehicleId: 'vehicle-a',
        key: 'schedule-1',
      ),
      'vehicle-smart:vehicle-a:schedule-1',
    );
    expect(
      vehicleSmartNotificationPayloadPrefix('vehicle-a'),
      'vehicle-smart:vehicle-a:',
    );
  });
}

VehicleMaintenanceSchedule _schedule(
  String id,
  String title,
  DateTime dueDate,
) {
  return VehicleMaintenanceSchedule(
    id: id,
    title: title,
    scheduleType: 'MAINTENANCE',
    status: 'ACTIVE',
    priority: 'MEDIUM',
    sourceType: 'AUTOCLAIR_RULE',
    reason: '',
    dueDate: dueDate,
  );
}

VehicleReminder _reminder(
  String id,
  String title,
  DateTime dueAt, {
  required String sourceType,
}) {
  return VehicleReminder(
    id: id,
    sourceType: sourceType,
    title: title,
    message: '',
    priority: 'MEDIUM',
    status: 'ACTIVE',
    dueAt: dueAt,
  );
}
