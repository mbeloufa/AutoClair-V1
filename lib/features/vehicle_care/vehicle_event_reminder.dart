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
