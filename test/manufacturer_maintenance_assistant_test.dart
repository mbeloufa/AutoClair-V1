import 'package:autoclair_app/features/vehicle_care/vehicle_assistant_brief.dart';
import 'package:autoclair_app/features/vehicle_care/vehicle_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleMaintenanceSchedule _schedule({
  required String id,
  required String title,
  required String sourceType,
  String? sourceKey,
  String? calculationBasis,
  String reason = '',
}) {
  return VehicleMaintenanceSchedule(
    id: id,
    title: title,
    scheduleType: 'MAINTENANCE',
    status: 'ACTIVE',
    priority: 'MEDIUM',
    sourceType: sourceType,
    reason: reason,
    sourceKey: sourceKey,
    calculationBasis: calculationBasis,
    dueDate: DateTime(2027, 5, 15),
  );
}

void main() {
  test(
    'generic and seasonal schedules are not promoted as assistant priorities',
    () {
      final generic = _schedule(
        id: 'generic',
        title: 'Contrôle périodique',
        sourceType: 'AUTOCLAIR_RULE',
        sourceKey: 'GENERIC:CHECK',
      );
      final seasonal = _schedule(
        id: 'seasonal',
        title: 'Contrôle climatisation avant l’été',
        sourceType: 'AUTOCLAIR_RULE',
        sourceKey: 'SEASONAL:CLIMATE',
        calculationBasis: 'SEASONAL_ADVICE',
        reason:
            'Pourquoi ? Vérifier la climatisation avant les fortes chaleurs.',
      );
      final manufacturer = _schedule(
        id: 'manufacturer',
        title: 'Liquide de frein',
        sourceType: 'AUTOCLAIR_RULE',
        sourceKey: 'MFR:abc:BRAKE_FLUID',
        calculationBasis: 'HISTORY_CONFIRMED',
        reason:
            'Pourquoi ? Le liquide de frein vieillit avec le temps. · Source.',
      );

      final filtered = assistantMaintenanceSchedules([
        generic,
        seasonal,
        manufacturer,
      ]);

      expect(filtered, hasLength(1));
      expect(filtered.single.id, 'manufacturer');
      expect(seasonal.planBadgeLabel, 'Conseil AutoClair');
      expect(manufacturer.planBadgeLabel, 'Constructeur + historique');
      expect(
        manufacturer.benefitText,
        'Le liquide de frein vieillit avec le temps.',
      );
    },
  );

  test('generic and seasonal schedule reminders are suppressed', () {
    final schedules = [
      _schedule(
        id: 'generic',
        title: 'Contrôle périodique',
        sourceType: 'AUTOCLAIR_RULE',
        sourceKey: 'GENERIC:CHECK',
      ),
      _schedule(
        id: 'seasonal',
        title: 'Contrôle climatisation avant l’été',
        sourceType: 'AUTOCLAIR_RULE',
        sourceKey: 'SEASONAL:CLIMATE',
      ),
    ];
    const genericReminder = VehicleReminder(
      id: 'r1',
      sourceType: 'SCHEDULE',
      title: 'Contrôle périodique',
      message: '',
      priority: 'MEDIUM',
      status: 'ACTIVE',
    );
    const seasonalReminder = VehicleReminder(
      id: 'r2',
      sourceType: 'SCHEDULE',
      title: 'Contrôle climatisation avant l’été',
      message: '',
      priority: 'LOW',
      status: 'ACTIVE',
    );
    const otherReminder = VehicleReminder(
      id: 'r3',
      sourceType: 'SCHEDULE',
      title: 'Liquide de frein',
      message: '',
      priority: 'MEDIUM',
      status: 'ACTIVE',
    );

    expect(assistantReminderIsEligible(genericReminder, schedules), isFalse);
    expect(assistantReminderIsEligible(seasonalReminder, schedules), isFalse);
    expect(assistantReminderIsEligible(otherReminder, schedules), isTrue);
  });
}
