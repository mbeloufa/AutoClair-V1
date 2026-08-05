import 'package:autoclair_app/features/vehicle_care/vehicle_event_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder date is calculated at 9 AM before the event', () {
    final reminder = vehicleEventReminderAt(
      eventDate: DateTime(2026, 9, 20, 12),
      daysBefore: 7,
    );

    expect(reminder, DateTime(2026, 9, 13, 9));
  });

  test('only proposed reminder delays are accepted', () {
    expect(isSupportedVehicleEventReminderDays(1), isTrue);
    expect(isSupportedVehicleEventReminderDays(30), isTrue);
    expect(isSupportedVehicleEventReminderDays(2), isFalse);
    expect(
      () => vehicleEventReminderAt(
        eventDate: DateTime(2026, 9, 20),
        daysBefore: 2,
      ),
      throwsArgumentError,
    );
  });

  test('notification id stays stable for the same event', () {
    final first = vehicleEventNotificationId('event-123');
    final second = vehicleEventNotificationId('event-123');
    expect(first, second);
    expect(first, greaterThan(0));
  });

  _lot3ReminderTests();
}

// Vérifie la resynchronisation des rappels prévue par le Lot 3.
void _lot3ReminderTests() {
  test('notification payloads stay scoped to their vehicle', () {
    final first = vehicleEventNotificationPayload(
      vehicleId: 'vehicle-a',
      eventKey: 'event-1',
    );
    final second = vehicleEventNotificationPayload(
      vehicleId: 'vehicle-b',
      eventKey: 'event-1',
    );

    expect(first, 'vehicle-event:vehicle-a:event-1');
    expect(second, isNot(first));
    expect(
      first.startsWith(vehicleEventNotificationPayloadPrefix('vehicle-a')),
      isTrue,
    );
  });

  test('only future reminder plans stay desired', () {
    final now = DateTime(2026, 8, 5, 12);
    final ids = desiredVehicleEventNotificationIds([
      VehicleEventReminderPlan(
        vehicleId: 'vehicle-1',
        eventKey: 'future',
        eventTitle: 'Révision',
        eventDate: DateTime(2026, 8, 20),
        daysBefore: 7,
      ),
      VehicleEventReminderPlan(
        vehicleId: 'vehicle-1',
        eventKey: 'past',
        eventTitle: 'Contrôle',
        eventDate: DateTime(2026, 8, 6),
        daysBefore: 7,
      ),
    ], now: now);

    expect(ids, contains(vehicleEventNotificationId('future')));
    expect(ids, isNot(contains(vehicleEventNotificationId('past'))));
  });
}
