import 'package:autoclair_app/features/vehicle_care/maintenance_v14_models.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleMaintenanceSchedule schedule({
  required String title,
  String? sourceKey,
  String? calculationBasis,
}) {
  return VehicleMaintenanceSchedule(
    id: title,
    title: title,
    scheduleType: 'MAINTENANCE',
    status: 'ACTIVE',
    priority: 'MEDIUM',
    sourceType: 'AUTOCLAIR_RULE',
    reason: '',
    sourceKey: sourceKey,
    calculationBasis: calculationBasis,
    dueDate: DateTime(2027, 3, 1),
  );
}

void main() {
  test('stable keys distinguish high-value maintenance reminders', () {
    expect(
      maintenanceV14StableKey(
        schedule(title: 'Contrôle technique', sourceKey: 'LEGAL:CT'),
      ),
      'regulatory:technical-control',
    );
    expect(
      maintenanceV14StableKey(
        schedule(title: 'Liquide de frein', sourceKey: 'MFR:abc:BRAKE_FLUID'),
      ),
      'maintenance:brake-fluid',
    );
    expect(
      maintenanceV14StableKey(
        schedule(title: 'Révision', sourceKey: 'MFR:abc:SERVICE'),
      ),
      'maintenance:service',
    );
  });

  test('first of date or projected mileage wins', () {
    final projected = maintenanceV14ProjectMileageDate(
      currentMileage: 90000,
      dueMileage: 95000,
      annualMileageKm: 20000,
      now: DateTime(2026, 8, 15),
    );
    expect(projected, isNotNull);
    expect(
      maintenanceV14FirstDueDate(
        calendarDue: DateTime(2027, 3, 1),
        mileageProjectedDue: projected,
      ),
      projected,
    );
  });

  test('season dates always point to the next useful season', () {
    expect(
      maintenanceV14NextSeasonDate(
        now: DateTime(2026, 8, 15),
        month: 4,
        day: 15,
      ),
      DateTime(2027, 4, 15, 9),
    );
    expect(
      maintenanceV14NextSeasonDate(
        now: DateTime(2026, 8, 15),
        month: 10,
        day: 1,
      ),
      DateTime(2026, 10, 1, 9),
    );
  });
}
