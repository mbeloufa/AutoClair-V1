import '../vehicle_care/vehicle_care_models.dart';
import '../vehicles/vehicle.dart';
import 'maintenance_planner_models.dart';

class MaintenancePlannerCalculator {
  MaintenancePlannerCalculator._();

  static MaintenancePlanSummary build({
    required Vehicle vehicle,
    required Iterable<VehicleMaintenanceSchedule> schedules,
    required MaintenancePlannerProfile profile,
    DateTime? now,
  }) {
    profile.validate();
    final reference = _dateOnly(now ?? DateTime.now());
    final filtered = schedules.where(
      (schedule) => _isRelevantForVehicle(schedule, vehicle),
    );

    final items =
        filtered
            .map(
              (schedule) => _buildItem(
                vehicle: vehicle,
                schedule: schedule,
                profile: profile,
                now: reference,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final urgency = left.urgency.index.compareTo(right.urgency.index);
            if (urgency != 0) return urgency;
            final leftDate = left.projectedDate ?? DateTime(9999);
            final rightDate = right.projectedDate ?? DateTime(9999);
            return leftDate.compareTo(rightDate);
          });

    var minimum = 0.0;
    var maximum = 0.0;
    var overdueCount = 0;
    var dueSoonCount = 0;

    for (final item in items) {
      if (item.urgency == MaintenanceForecastUrgency.overdue) {
        overdueCount++;
      }
      if (item.urgency == MaintenanceForecastUrgency.dueSoon) {
        dueSoonCount++;
      }
      if (!item.contributesToTwelveMonthBudget) continue;
      final buffered = item.costRange.withBuffer(profile.budgetBufferPercent);
      minimum += buffered.minimum;
      maximum += buffered.maximum;
    }

    final twelveMonth = MaintenanceCostRange(
      minimum: minimum,
      maximum: maximum,
    );

    return MaintenancePlanSummary(
      items: List.unmodifiable(items),
      twelveMonthCost: twelveMonth,
      monthlyReserve: MaintenanceCostRange(
        minimum: minimum / 12,
        maximum: maximum / 12,
      ),
      overdueCount: overdueCount,
      dueSoonCount: dueSoonCount,
    );
  }

  static MaintenanceForecastItem _buildItem({
    required Vehicle vehicle,
    required VehicleMaintenanceSchedule schedule,
    required MaintenancePlannerProfile profile,
    required DateTime now,
  }) {
    final currentMileage = vehicle.mileage;
    final projectedDate = _projectDate(
      schedule: schedule,
      currentMileage: currentMileage,
      annualMileageKm: profile.annualMileageKm,
      now: now,
    );
    final projectedMileage = _projectMileage(
      schedule: schedule,
      currentMileage: currentMileage,
      annualMileageKm: profile.annualMileageKm,
      now: now,
    );
    final urgency = _urgency(
      schedule: schedule,
      projectedDate: projectedDate,
      projectedMileage: projectedMileage,
      currentMileage: currentMileage,
      annualMileageKm: profile.annualMileageKm,
      now: now,
    );
    final dueParts = <String>[];
    if (schedule.dueDate == null && projectedDate != null) {
      dueParts.add('date estimée selon votre kilométrage annuel');
    }
    if (schedule.dueMileage == null && projectedMileage != null) {
      dueParts.add('kilométrage estimé selon votre usage');
    }
    if (dueParts.isEmpty) {
      dueParts.add('échéance issue du carnet AutoClair');
    }

    return MaintenanceForecastItem(
      schedule: schedule,
      urgency: urgency,
      costRange: _costFor(schedule.title),
      reason: dueParts.join(' • '),
      projectedDate: projectedDate,
      projectedMileage: projectedMileage,
    );
  }

  static DateTime? _projectDate({
    required VehicleMaintenanceSchedule schedule,
    required int? currentMileage,
    required int annualMileageKm,
    required DateTime now,
  }) {
    if (schedule.dueDate != null) return _dateOnly(schedule.dueDate!);
    if (schedule.dueMileage == null || currentMileage == null) return null;
    final remainingKm = schedule.dueMileage! - currentMileage;
    if (remainingKm <= 0) return now;
    final days = (remainingKm / annualMileageKm * 365).round();
    return _addCalendarDays(now, days);
  }

  static int? _projectMileage({
    required VehicleMaintenanceSchedule schedule,
    required int? currentMileage,
    required int annualMileageKm,
    required DateTime now,
  }) {
    if (schedule.dueMileage != null) return schedule.dueMileage;
    if (schedule.dueDate == null || currentMileage == null) return null;
    final days = _calendarDayDifference(_dateOnly(schedule.dueDate!), now);
    if (days <= 0) return currentMileage;
    return currentMileage + (annualMileageKm * days / 365).round();
  }

  static MaintenanceForecastUrgency _urgency({
    required VehicleMaintenanceSchedule schedule,
    required DateTime? projectedDate,
    required int? projectedMileage,
    required int? currentMileage,
    required int annualMileageKm,
    required DateTime now,
  }) {
    if (schedule.isOverdue(currentMileage: currentMileage, now: now)) {
      return MaintenanceForecastUrgency.overdue;
    }

    final dateDueSoon =
        projectedDate != null &&
        !projectedDate.isAfter(_addCalendarDays(now, 60));
    final mileageDueSoon =
        currentMileage != null &&
        projectedMileage != null &&
        projectedMileage <= currentMileage + 2000;
    if (dateDueSoon || mileageDueSoon) {
      return MaintenanceForecastUrgency.dueSoon;
    }

    final dateWithinYear =
        projectedDate != null &&
        !projectedDate.isAfter(_addCalendarDays(now, 365));
    final mileageWithinYear =
        currentMileage != null &&
        projectedMileage != null &&
        projectedMileage <= currentMileage + annualMileageKm;
    if (dateWithinYear || mileageWithinYear) {
      return MaintenanceForecastUrgency.nextTwelveMonths;
    }

    if (projectedDate != null || projectedMileage != null) {
      return MaintenanceForecastUrgency.later;
    }
    return MaintenanceForecastUrgency.unknown;
  }

  static bool _isRelevantForVehicle(
    VehicleMaintenanceSchedule schedule,
    Vehicle vehicle,
  ) {
    final fuel = _normalize(vehicle.fuelType ?? '');
    final title = _normalize(schedule.title);
    final electric = fuel.contains('electri') && !fuel.contains('hybrid');
    if (!electric) return true;
    return !title.contains('vidange') &&
        !title.contains('huile moteur') &&
        !title.contains('distribution');
  }

  static MaintenanceCostRange _costFor(String title) {
    final value = _normalize(title);
    if (_containsAny(value, ['vidange', 'revision', 'huile moteur'])) {
      return const MaintenanceCostRange(minimum: 150, maximum: 350);
    }
    if (_containsAny(value, ['filtre', 'fluide', 'liquide'])) {
      return const MaintenanceCostRange(minimum: 80, maximum: 260);
    }
    if (_containsAny(value, ['distribution', 'courroie', 'pompe a eau'])) {
      return const MaintenanceCostRange(minimum: 650, maximum: 1500);
    }
    if (_containsAny(value, ['climatisation', 'clim'])) {
      return const MaintenanceCostRange(minimum: 80, maximum: 200);
    }
    if (_containsAny(value, ['frein', 'plaquette', 'disque'])) {
      return const MaintenanceCostRange(minimum: 250, maximum: 750);
    }
    if (_containsAny(value, ['pneu', 'pneumatique'])) {
      return const MaintenanceCostRange(minimum: 300, maximum: 900);
    }
    if (_containsAny(value, ['batterie', 'electrique', 'electricite'])) {
      return const MaintenanceCostRange(minimum: 120, maximum: 380);
    }
    if (_containsAny(value, ['suspension', 'direction', 'amortisseur'])) {
      return const MaintenanceCostRange(minimum: 300, maximum: 1200);
    }
    if (_containsAny(value, ['echappement', 'catalyseur'])) {
      return const MaintenanceCostRange(minimum: 180, maximum: 900);
    }
    if (_containsAny(value, ['controle technique', 'inspection'])) {
      return const MaintenanceCostRange(minimum: 70, maximum: 120);
    }
    return const MaintenanceCostRange(minimum: 100, maximum: 500);
  }

  static bool _containsAny(String value, Iterable<String> tokens) {
    for (final token in tokens) {
      if (value.contains(token)) return true;
    }
    return false;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâäãå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[òóôöõ]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static DateTime _addCalendarDays(DateTime value, int days) {
    final localDate = _dateOnly(value);
    final utcDate = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
    ).add(Duration(days: days));
    return DateTime(utcDate.year, utcDate.month, utcDate.day);
  }

  static int _calendarDayDifference(DateTime later, DateTime earlier) {
    final laterDate = _dateOnly(later);
    final earlierDate = _dateOnly(earlier);
    final laterUtc = DateTime.utc(
      laterDate.year,
      laterDate.month,
      laterDate.day,
    );
    final earlierUtc = DateTime.utc(
      earlierDate.year,
      earlierDate.month,
      earlierDate.day,
    );
    return laterUtc.difference(earlierUtc).inDays;
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
