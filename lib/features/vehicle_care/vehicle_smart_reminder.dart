import 'vehicle_care_models.dart';
import 'vehicle_maintenance_presentation.dart';

const int maxVehicleSmartReminders = 3;

class VehicleSmartReminderPlan {
  const VehicleSmartReminderPlan({
    required this.vehicleId,
    required this.key,
    required this.title,
    required this.dueAt,
    required this.reminderAt,
  });

  final String vehicleId;
  final String key;
  final String title;
  final DateTime dueAt;
  final DateTime reminderAt;

  int get notificationId =>
      vehicleSmartNotificationId(vehicleId: vehicleId, key: key);

  bool isFutureAt(DateTime now) => reminderAt.isAfter(now);
}

List<VehicleSmartReminderPlan> buildVehicleSmartReminderPlans({
  required String vehicleId,
  required Iterable<VehicleMaintenanceSchedule> schedules,
  required Iterable<VehicleReminder> reminders,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final candidates = <_SmartReminderCandidate>[];

  final maintenanceGroups = groupVehicleMaintenanceSchedules(
    schedules,
    now: reference,
  );
  for (final group in maintenanceGroups) {
    final dueDate = group.dueDate;
    if (dueDate == null ||
        group.schedules.every(
          (schedule) => schedule.status.toUpperCase() == 'COMPLETED',
        )) {
      continue;
    }

    final reminderAt = vehicleSmartReminderAt(dueAt: dueDate, now: reference);
    if (reminderAt == null) continue;

    candidates.add(
      _SmartReminderCandidate(
        priority: group.schedules
            .map((schedule) => _priorityRank(schedule.priority))
            .reduce((left, right) => left < right ? left : right),
        dueAt: dueDate,
        plan: VehicleSmartReminderPlan(
          vehicleId: vehicleId,
          key: 'schedule:${group.schedules.map((item) => item.id).join('+')}',
          title: group.title,
          dueAt: dueDate,
          reminderAt: reminderAt,
        ),
      ),
    );
  }

  for (final reminder in reminders) {
    final dueAt = reminder.dueAt;
    final source = reminder.sourceType.toUpperCase();
    if (dueAt == null ||
        reminder.status.toUpperCase() != 'ACTIVE' ||
        source.contains('RECALL') ||
        source.contains('EVENT')) {
      continue;
    }

    final reminderAt = vehicleSmartReminderAt(dueAt: dueAt, now: reference);
    if (reminderAt == null) continue;

    candidates.add(
      _SmartReminderCandidate(
        priority: _priorityRank(reminder.priority),
        dueAt: dueAt,
        plan: VehicleSmartReminderPlan(
          vehicleId: vehicleId,
          key: 'reminder:${reminder.id}',
          title: vehicleMaintenanceDisplayTitle(reminder.title),
          dueAt: dueAt,
          reminderAt: reminderAt,
        ),
      ),
    );
  }

  candidates.sort((left, right) {
    final dueComparison = left.dueAt.compareTo(right.dueAt);
    if (dueComparison != 0) return dueComparison;
    return left.priority.compareTo(right.priority);
  });

  final seenTitles = <String>{};
  final result = <VehicleSmartReminderPlan>[];

  for (final candidate in candidates) {
    final titleKey = _normalizedTitle(candidate.plan.title);
    if (titleKey.isNotEmpty && !seenTitles.add(titleKey)) continue;
    result.add(candidate.plan);
    if (result.length == maxVehicleSmartReminders) break;
  }

  return List.unmodifiable(result);
}

DateTime? vehicleSmartReminderAt({
  required DateTime dueAt,
  required DateTime now,
}) {
  final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day, 9);
  final today = DateTime(now.year, now.month, now.day);
  final daysUntilDue = dueDay.difference(today).inDays;

  if (daysUntilDue <= 1) return null;

  final daysBefore = daysUntilDue > 14
      ? 14
      : daysUntilDue > 3
      ? 3
      : 1;
  final reminderAt = dueDay.subtract(Duration(days: daysBefore));

  return reminderAt.isAfter(now) ? reminderAt : null;
}

int vehicleSmartNotificationId({
  required String vehicleId,
  required String key,
}) {
  final raw = 'vehicle-smart:$vehicleId:$key';
  var hash = 0x811C9DC5;
  for (final unit in raw.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash == 0 ? 1 : hash;
}

String vehicleSmartNotificationPayload({
  required String vehicleId,
  required String key,
}) => 'vehicle-smart:$vehicleId:$key';

String vehicleSmartNotificationPayloadPrefix(String vehicleId) =>
    'vehicle-smart:$vehicleId:';

class _SmartReminderCandidate {
  const _SmartReminderCandidate({
    required this.priority,
    required this.dueAt,
    required this.plan,
  });

  final int priority;
  final DateTime dueAt;
  final VehicleSmartReminderPlan plan;
}

int _priorityRank(String priority) => switch (priority.toUpperCase()) {
  'CRITICAL' => 0,
  'HIGH' => 1,
  'MEDIUM' => 2,
  _ => 3,
};

String _normalizedTitle(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüÿ]+'), ' ')
    .trim();
