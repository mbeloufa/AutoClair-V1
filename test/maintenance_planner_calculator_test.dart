import 'package:autoclair_app/features/maintenance_planner/maintenance_planner_calculator.dart';
import 'package:autoclair_app/features/maintenance_planner/maintenance_planner_models.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:autoclair_app/features/vehicles/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 5);

  test('projects a mileage deadline and builds a twelve-month budget', () {
    final summary = MaintenancePlannerCalculator.build(
      vehicle: _vehicle(mileage: 50000),
      schedules: [
        _schedule(
          id: 'service',
          title: 'Révision et vidange',
          dueMileage: 56000,
        ),
      ],
      profile: const MaintenancePlannerProfile(
        annualMileageKm: 12000,
        budgetBufferPercent: 10,
        reminderDaysBefore: 30,
      ),
      now: now,
    );

    expect(summary.items, hasLength(1));
    final item = summary.items.single;
    expect(item.urgency, MaintenanceForecastUrgency.nextTwelveMonths);
    expect(item.projectedDate, DateTime(2027, 2, 4));
    expect(item.projectedDate?.hour, 0);
    expect(item.projectedDate?.minute, 0);
    expect(summary.twelveMonthCost.minimum, closeTo(165, 0.001));
    expect(summary.twelveMonthCost.maximum, closeTo(385, 0.001));
    expect(summary.monthlyReserve.minimum, closeTo(13.75, 0.001));
    expect(summary.monthlyReserve.maximum, closeTo(32.0833, 0.001));
  });

  test('places overdue maintenance first and counts it', () {
    final summary = MaintenancePlannerCalculator.build(
      vehicle: _vehicle(mileage: 50000),
      schedules: [
        _schedule(
          id: 'later',
          title: 'Climatisation',
          dueDate: DateTime(2028, 1, 1),
        ),
        _schedule(id: 'late', title: 'Freinage', dueMileage: 49000),
      ],
      profile: MaintenancePlannerProfile.defaults(),
      now: now,
    );

    expect(summary.items.first.schedule.id, 'late');
    expect(summary.items.first.urgency, MaintenanceForecastUrgency.overdue);
    expect(summary.overdueCount, 1);
  });

  test('filters thermal-only maintenance for an electric vehicle', () {
    final summary = MaintenancePlannerCalculator.build(
      vehicle: _vehicle(mileage: 20000, fuelType: 'Électrique'),
      schedules: [
        _schedule(id: 'oil', title: 'Vidange moteur', dueMileage: 25000),
        _schedule(id: 'timing', title: 'Distribution', dueMileage: 90000),
        _schedule(id: 'tyres', title: 'Pneus', dueMileage: 30000),
      ],
      profile: MaintenancePlannerProfile.defaults(),
      now: now,
    );

    expect(summary.items.map((item) => item.schedule.id).toList(), ['tyres']);
  });

  test('projects mileage from a date-only schedule', () {
    final summary = MaintenancePlannerCalculator.build(
      vehicle: _vehicle(mileage: 40000),
      schedules: [
        _schedule(
          id: 'filters',
          title: 'Filtres et fluides',
          dueDate: DateTime(2027, 2, 5),
        ),
      ],
      profile: const MaintenancePlannerProfile(
        annualMileageKm: 10000,
        budgetBufferPercent: 0,
        reminderDaysBefore: 14,
      ),
      now: now,
    );

    expect(summary.items.single.projectedMileage, 45041);
    expect(
      summary.items.single.urgency,
      MaintenanceForecastUrgency.nextTwelveMonths,
    );
  });

  test('keeps projected dates at local midnight across spring DST', () {
    final summary = MaintenancePlannerCalculator.build(
      vehicle: _vehicle(mileage: 50000),
      schedules: [
        _schedule(id: 'spring-service', title: 'Révision', dueMileage: 56000),
      ],
      profile: const MaintenancePlannerProfile(
        annualMileageKm: 36500,
        budgetBufferPercent: 0,
        reminderDaysBefore: 30,
      ),
      now: DateTime(2027, 2, 1),
    );

    final projected = summary.items.single.projectedDate;
    expect(projected, DateTime(2027, 4, 2));
    expect(projected?.hour, 0);
    expect(projected?.minute, 0);
  });

  test('counts calendar days across spring DST for mileage projection', () {
    final summary = MaintenancePlannerCalculator.build(
      vehicle: _vehicle(mileage: 40000),
      schedules: [
        _schedule(
          id: 'spring-filters',
          title: 'Filtres',
          dueDate: DateTime(2027, 4, 2),
        ),
      ],
      profile: const MaintenancePlannerProfile(
        annualMileageKm: 36500,
        budgetBufferPercent: 0,
        reminderDaysBefore: 14,
      ),
      now: DateTime(2027, 2, 1),
    );

    expect(summary.items.single.projectedMileage, 46000);
  });
}

Vehicle _vehicle({required int mileage, String fuelType = 'Essence'}) {
  return Vehicle(
    id: 'vehicle-1',
    userId: 'user-1',
    make: 'Renault',
    model: 'Clio',
    fuelType: fuelType,
    mileage: mileage,
    isPrimary: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

VehicleMaintenanceSchedule _schedule({
  required String id,
  required String title,
  DateTime? dueDate,
  int? dueMileage,
}) {
  return VehicleMaintenanceSchedule(
    id: id,
    title: title,
    scheduleType: 'MAINTENANCE',
    status: 'ACTIVE',
    priority: 'MEDIUM',
    sourceType: 'AUTOCLAIR_RULE',
    reason: 'Plan indicatif',
    dueDate: dueDate,
    dueMileage: dueMileage,
  );
}
