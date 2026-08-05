import 'package:autoclair_app/features/breakdown_assistant/breakdown_assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes a saved assistance phone for calling', () {
    const profile = BreakdownAssistantProfile(
      assistanceProvider: 'Assureur',
      assistancePhone: '+33 (0)1 23 45 67 89',
      contractReference: 'CTR-1234',
      assistanceZeroKm: true,
    );

    profile.validate();
    expect(profile.callablePhone, '+330123456789');
  });

  test('rejects an invalid assistance phone', () {
    const profile = BreakdownAssistantProfile(assistancePhone: '12');
    expect(profile.validate, throwsFormatException);
  });

  test('summary contains facts but no route coordinates', () {
    const input = BreakdownAssessmentInput(
      locationType: BreakdownLocationType.road,
      symptoms: {BreakdownSymptom.tyreDamage},
      safelyParked: true,
      vehicleInTrafficLane: false,
      injuredPerson: false,
      vehicleCanMove: false,
    );
    const assessment = BreakdownAssessment(
      actionLevel: BreakdownActionLevel.assistanceRecommended,
      title: 'Assistance',
      explanation: 'Pneu endommagé.',
      immediateSteps: [],
      safeChecks: [],
      thingsToAvoid: [],
      shouldCall112: false,
      shouldCallAssistance: true,
      mayDrive: false,
      eventType: 'TYRES',
      categoryCode: 'SAFETY',
      subcategoryCode: 'TYRES',
      symptomCodes: ['TYRE_DAMAGE'],
    );

    final summary = assessment.buildShareSummary(
      vehicleName: 'Golf',
      input: input,
      mileage: 120000,
    );

    expect(summary, contains('Véhicule : Golf'));
    expect(summary, contains('Pneu crevé'));
    expect(summary.toLowerCase(), isNot(contains('latitude')));
    expect(summary.toLowerCase(), isNot(contains('longitude')));
  });

  test('parses a recent stored case', () {
    final item = BreakdownCaseSummary.fromMap({
      'id': 'case-1',
      'occurred_at': '2026-08-05T20:00:00Z',
      'action_level': 'GARAGE_SOON',
      'location_type': 'ROAD',
      'symptom_codes': ['UNUSUAL_NOISE'],
      'summary': 'Bruit inhabituel.',
    });

    expect(item.id, 'case-1');
    expect(item.symptomCodes, ['UNUSUAL_NOISE']);
  });
}
