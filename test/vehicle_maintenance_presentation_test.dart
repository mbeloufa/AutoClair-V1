import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_maintenance_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('oil service components become one realistic revision', () {
    final groups = groupVehicleMaintenanceSchedules(
      [
        _schedule('oil', 'Vidange moteur', DateTime(2026, 9, 10), 80000),
        _schedule('filter', 'Filtre à huile', DateTime(2026, 9, 10), 80000),
        _schedule('cabin', 'Filtre habitacle', DateTime(2026, 12, 10), 90000),
      ],
      currentMileage: 79000,
      now: DateTime(2026, 8, 10),
    );

    expect(groups, hasLength(2));
    expect(groups.first.title, 'Révision avec vidange');
    expect(groups.first.schedules, hasLength(2));
    expect(groups.first.dueMileage, 80000);
  });

  test('same operation at distant intervals stays separate', () {
    final groups = groupVehicleMaintenanceSchedules(
      [
        _schedule('oil-1', 'Vidange', DateTime(2026, 9, 10), 80000),
        _schedule('oil-2', 'Révision', DateTime(2027, 9, 10), 100000),
      ],
      currentMileage: 78000,
      now: DateTime(2026, 8, 10),
    );

    expect(groups, hasLength(2));
    expect(
      groups.every((group) => group.title == 'Révision avec vidange'),
      isTrue,
    );
  });
}

VehicleMaintenanceSchedule _schedule(
  String id,
  String title,
  DateTime dueDate,
  int mileage,
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
    dueMileage: mileage,
  );
}
