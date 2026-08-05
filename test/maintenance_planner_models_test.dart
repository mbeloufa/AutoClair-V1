import 'package:autoclair_app/features/maintenance_planner/maintenance_planner_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and validates a stored maintenance planner profile', () {
    final profile = MaintenancePlannerProfile.fromMap({
      'annual_mileage_km': 18000,
      'budget_buffer_percent': 15,
      'reminder_days_before': 14,
    });

    expect(profile.annualMileageKm, 18000);
    expect(profile.budgetBufferPercent, 15);
    expect(profile.reminderDaysBefore, 14);
    expect(profile.validate, returnsNormally);
  });

  test('rejects unsupported reminder and invalid annual mileage', () {
    const unsupportedReminder = MaintenancePlannerProfile(
      annualMileageKm: 12000,
      budgetBufferPercent: 10,
      reminderDaysBefore: 60,
    );
    const invalidMileage = MaintenancePlannerProfile(
      annualMileageKm: 500,
      budgetBufferPercent: 10,
      reminderDaysBefore: 30,
    );

    expect(unsupportedReminder.validate, throwsA(isA<FormatException>()));
    expect(invalidMileage.validate, throwsA(isA<FormatException>()));
  });

  test('adds a budget buffer without changing the source range', () {
    const range = MaintenanceCostRange(minimum: 100, maximum: 300);
    final buffered = range.withBuffer(10);

    expect(buffered.minimum, closeTo(110, 0.001));
    expect(buffered.maximum, closeTo(330, 0.001));
    expect(range.minimum, 100);
    expect(range.maximum, 300);
  });
}
