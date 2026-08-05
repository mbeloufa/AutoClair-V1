const List<int> supportedVehicleEventReminderDays = <int>[1, 3, 7, 14, 30];

bool isSupportedVehicleEventReminderDays(int value) {
  return supportedVehicleEventReminderDays.contains(value);
}

DateTime vehicleEventReminderAt({
  required DateTime eventDate,
  required int daysBefore,
}) {
  if (!isSupportedVehicleEventReminderDays(daysBefore)) {
    throw ArgumentError.value(
      daysBefore,
      'daysBefore',
      'Le délai de rappel doit être 1, 3, 7, 14 ou 30 jours.',
    );
  }

  final eventMorning = DateTime(
    eventDate.year,
    eventDate.month,
    eventDate.day,
    9,
  );
  return eventMorning.subtract(Duration(days: daysBefore));
}

int vehicleEventNotificationId(String eventKey) {
  var hash = 0x811C9DC5;
  for (final unit in eventKey.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash == 0 ? 1 : hash;
}

String vehicleEventNotificationPayload({
  required String vehicleId,
  required String eventKey,
}) => 'vehicle-event:$vehicleId:$eventKey';

String vehicleEventNotificationPayloadPrefix(String vehicleId) =>
    'vehicle-event:$vehicleId:';

class VehicleEventReminderPlan {
  const VehicleEventReminderPlan({
    required this.vehicleId,
    required this.eventKey,
    required this.eventTitle,
    required this.eventDate,
    required this.daysBefore,
  });

  final String vehicleId;
  final String eventKey;
  final String eventTitle;
  final DateTime eventDate;
  final int daysBefore;

  DateTime get reminderAt =>
      vehicleEventReminderAt(eventDate: eventDate, daysBefore: daysBefore);

  int get notificationId => vehicleEventNotificationId(eventKey);

  bool isFutureAt(DateTime now) => reminderAt.isAfter(now);
}

Set<int> desiredVehicleEventNotificationIds(
  Iterable<VehicleEventReminderPlan> plans, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  return plans
      .where((plan) => plan.isFutureAt(reference))
      .map((plan) => plan.notificationId)
      .toSet();
}
