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
}
