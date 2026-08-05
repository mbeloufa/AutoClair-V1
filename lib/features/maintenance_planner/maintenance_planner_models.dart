import '../vehicle_care/vehicle_care_models.dart';
import '../vehicle_care/vehicle_event_reminder.dart';

class MaintenancePlannerProfile {
  const MaintenancePlannerProfile({
    required this.annualMileageKm,
    required this.budgetBufferPercent,
    required this.reminderDaysBefore,
  });

  final int annualMileageKm;
  final double budgetBufferPercent;
  final int reminderDaysBefore;

  factory MaintenancePlannerProfile.defaults() {
    return const MaintenancePlannerProfile(
      annualMileageKm: 12000,
      budgetBufferPercent: 10,
      reminderDaysBefore: 30,
    );
  }

  factory MaintenancePlannerProfile.fromMap(Map<String, dynamic> map) {
    return MaintenancePlannerProfile(
      annualMileageKm: _integer(map['annual_mileage_km'], fallback: 12000),
      budgetBufferPercent: _decimal(map['budget_buffer_percent'], fallback: 10),
      reminderDaysBefore: _integer(map['reminder_days_before'], fallback: 30),
    );
  }

  void validate() {
    if (annualMileageKm < 1000 || annualMileageKm > 100000) {
      throw const FormatException(
        'Le kilométrage annuel doit être compris entre 1 000 et 100 000 km.',
      );
    }
    if (budgetBufferPercent < 0 || budgetBufferPercent > 50) {
      throw const FormatException(
        'La marge budgétaire doit être comprise entre 0 et 50 %.',
      );
    }
    if (!isSupportedVehicleEventReminderDays(reminderDaysBefore)) {
      throw const FormatException(
        'Le délai de rappel doit être 1, 3, 7, 14 ou 30 jours.',
      );
    }
  }
}

class MaintenanceCostRange {
  const MaintenanceCostRange({required this.minimum, required this.maximum});

  final double minimum;
  final double maximum;

  double get midpoint => (minimum + maximum) / 2;

  MaintenanceCostRange withBuffer(double percent) {
    final factor = 1 + percent / 100;
    return MaintenanceCostRange(
      minimum: minimum * factor,
      maximum: maximum * factor,
    );
  }
}

enum MaintenanceForecastUrgency {
  overdue,
  dueSoon,
  nextTwelveMonths,
  later,
  unknown,
}

extension MaintenanceForecastUrgencyX on MaintenanceForecastUrgency {
  String get label => switch (this) {
    MaintenanceForecastUrgency.overdue => 'En retard',
    MaintenanceForecastUrgency.dueSoon => 'À prévoir bientôt',
    MaintenanceForecastUrgency.nextTwelveMonths => 'Dans les 12 mois',
    MaintenanceForecastUrgency.later => 'Plus tard',
    MaintenanceForecastUrgency.unknown => 'À confirmer',
  };
}

class MaintenanceForecastItem {
  const MaintenanceForecastItem({
    required this.schedule,
    required this.urgency,
    required this.costRange,
    required this.reason,
    this.projectedDate,
    this.projectedMileage,
  });

  final VehicleMaintenanceSchedule schedule;
  final MaintenanceForecastUrgency urgency;
  final MaintenanceCostRange costRange;
  final String reason;
  final DateTime? projectedDate;
  final int? projectedMileage;

  bool get contributesToTwelveMonthBudget =>
      urgency == MaintenanceForecastUrgency.overdue ||
      urgency == MaintenanceForecastUrgency.dueSoon ||
      urgency == MaintenanceForecastUrgency.nextTwelveMonths;
}

class MaintenancePlanSummary {
  const MaintenancePlanSummary({
    required this.items,
    required this.twelveMonthCost,
    required this.monthlyReserve,
    required this.overdueCount,
    required this.dueSoonCount,
  });

  final List<MaintenanceForecastItem> items;
  final MaintenanceCostRange twelveMonthCost;
  final MaintenanceCostRange monthlyReserve;
  final int overdueCount;
  final int dueSoonCount;

  bool get isEmpty => items.isEmpty;
}

int _integer(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _decimal(dynamic value, {required double fallback}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
