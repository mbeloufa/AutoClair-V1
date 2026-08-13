import 'vehicle_care_models.dart';

class VehicleMaintenanceGroup {
  const VehicleMaintenanceGroup({required this.title, required this.schedules});

  final String title;
  final List<VehicleMaintenanceSchedule> schedules;

  VehicleMaintenanceSchedule get primary => schedules.first;

  bool get isManufacturerPlan =>
      schedules.any((item) => item.isManufacturerPlan);

  String get sourceBadgeLabel =>
      isManufacturerPlan ? 'Plan constructeur' : 'Contrôle périodique';

  DateTime? get dueDate {
    final dates =
        schedules
            .map((item) => item.dueDate)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  int? get dueMileage {
    final mileages =
        schedules
            .map((item) => item.dueMileage)
            .whereType<int>()
            .toList(growable: false)
          ..sort();
    return mileages.isEmpty ? null : mileages.first;
  }

  bool isOverdue({required int? currentMileage, DateTime? now}) {
    return schedules.any(
      (item) => item.isOverdue(currentMileage: currentMileage, now: now),
    );
  }

  bool isDueSoon({required int? currentMileage, DateTime? now}) {
    if (isOverdue(currentMileage: currentMileage, now: now)) return false;
    return schedules.any(
      (item) => item.isDueSoon(currentMileage: currentMileage, now: now),
    );
  }
}

List<VehicleMaintenanceGroup> groupVehicleMaintenanceSchedules(
  Iterable<VehicleMaintenanceSchedule> values, {
  int? currentMileage,
  DateTime? now,
}) {
  final ordered = orderedMaintenanceSchedules(
    values,
    currentMileage: currentMileage,
    now: now,
  );
  final groups = <_MutableMaintenanceGroup>[];

  for (final schedule in ordered) {
    final title = vehicleMaintenanceDisplayTitle(schedule.title);
    _MutableMaintenanceGroup? target;

    for (final group in groups.reversed) {
      if (group.title != title) continue;
      if (_sameMaintenanceWindow(group.schedules.first, schedule)) {
        target = group;
        break;
      }
    }

    if (target == null) {
      groups.add(
        _MutableMaintenanceGroup(
          title: title,
          schedules: <VehicleMaintenanceSchedule>[schedule],
        ),
      );
    } else {
      target.schedules.add(schedule);
    }
  }

  return List.unmodifiable(
    groups.map(
      (group) => VehicleMaintenanceGroup(
        title: group.title,
        schedules: List.unmodifiable(group.schedules),
      ),
    ),
  );
}

String vehicleMaintenanceDisplayTitle(String rawTitle) {
  final normalized = _normalizeMaintenanceTitle(rawTitle);

  final oilService =
      normalized.contains('vidange') ||
      normalized.contains('revision') ||
      normalized.contains('filtre a huile') ||
      normalized.contains('huile moteur') ||
      normalized == 'huile';

  if (oilService) return 'Révision avec vidange';

  if (normalized.contains('controle technique')) {
    return 'Contrôle technique';
  }
  if (normalized.contains('courroie') || normalized.contains('distribution')) {
    return 'Distribution';
  }
  if (normalized.contains('liquide de frein')) {
    return 'Liquide de frein';
  }

  final trimmed = rawTitle.trim();
  return trimmed.isEmpty ? 'Entretien' : trimmed;
}

bool _sameMaintenanceWindow(
  VehicleMaintenanceSchedule left,
  VehicleMaintenanceSchedule right,
) {
  final leftDate = left.dueDate;
  final rightDate = right.dueDate;
  if (leftDate != null && rightDate != null) {
    if (leftDate.difference(rightDate).inDays.abs() <= 45) return true;
  }

  final leftMileage = left.dueMileage;
  final rightMileage = right.dueMileage;
  if (leftMileage != null && rightMileage != null) {
    if ((leftMileage - rightMileage).abs() <= 2500) return true;
  }

  return false;
}

String _normalizeMaintenanceTitle(String value) {
  var normalized = value.toLowerCase();
  const replacements = <String, String>{
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _MutableMaintenanceGroup {
  _MutableMaintenanceGroup({required this.title, required this.schedules});

  final String title;
  final List<VehicleMaintenanceSchedule> schedules;
}
