import 'package:autoclair_app/features/vehicle_care/vehicle_assistant_brief.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generic AutoClair schedules are not promoted as assistant priorities',
    () {
      final generic = VehicleMaintenanceSchedule.fromMap({
        'id': 'generic',
        'title': 'Révision avec vidange',
        'schedule_type': 'MAINTENANCE',
        'status': 'ACTIVE',
        'priority': 'HIGH',
        'source_type': 'AUTOCLAIR_RULE',
        'reason': 'Règle indicative',
      });
      final manufacturer = VehicleMaintenanceSchedule.fromMap({
        'id': 'manufacturer',
        'title': 'Liquide de frein',
        'schedule_type': 'MAINTENANCE',
        'status': 'ACTIVE',
        'priority': 'MEDIUM',
        'source_type': 'AUTOCLAIR_RULE',
        'source_key': 'MFR:abc:brake-fluid',
        'source_url': 'https://www.volkswagen.fr/entretien',
        'source_label': 'Volkswagen',
        'source_quality': 'OFFICIAL_EXACT',
        'calculation_basis': 'THEORETICAL_CYCLE',
        'reason': 'Constructeur',
      });

      final effective = assistantMaintenanceSchedules([generic, manufacturer]);
      expect(effective.map((item) => item.id), ['manufacturer']);
      expect(generic.isGenericPlan, isTrue);
      expect(manufacturer.isManufacturerPlan, isTrue);
    },
  );

  test('schedule reminder matching a generic rule is suppressed', () {
    final generic = VehicleMaintenanceSchedule.fromMap({
      'id': 'generic',
      'title': 'Vidange moteur',
      'schedule_type': 'MAINTENANCE',
      'status': 'ACTIVE',
      'priority': 'HIGH',
      'source_type': 'AUTOCLAIR_RULE',
      'reason': '',
    });
    final reminder = VehicleReminder.fromMap({
      'id': 'r1',
      'source_type': 'SCHEDULE',
      'title': 'Vidange moteur',
      'message': '',
      'priority': 'HIGH',
      'status': 'ACTIVE',
    });
    expect(assistantReminderIsEligible(reminder, [generic]), isFalse);
  });
}
