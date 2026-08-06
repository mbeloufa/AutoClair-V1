import 'package:autoclair_app/features/accident_assistant/accident_assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes insurer phone numbers for direct calling', () {
    const profile = AccidentAssistantProfile(
      vehicleId: 'vehicle-1',
      insurerName: 'Assureur test',
      claimPhone: '01 23 45 67 89',
      assistancePhone: '+33 (0)1 40 00 00 00',
      contractReference: 'AUTO-123',
      memoVehicleInsuredAvailable: true,
    );

    expect(profile.callableClaimPhone, '0123456789');
    expect(profile.callableAssistancePhone, '+330140000000');
    expect(() => profile.validate(), returnsNormally);
  });

  test('rejects an invalid insurer phone', () {
    const profile = AccidentAssistantProfile(
      vehicleId: 'vehicle-1',
      insurerName: '',
      claimPhone: '12',
      assistancePhone: '',
      contractReference: '',
      memoVehicleInsuredAvailable: false,
    );

    expect(profile.validate, throwsFormatException);
  });

  test('summary contains facts but no third-party identity', () {
    final input = AccidentCaseInput(
      vehicleId: 'vehicle-1',
      occurredAt: DateTime(2026, 8, 6),
      locationType: AccidentLocationType.urban,
      injured: false,
      immediateDanger: false,
      vehicleCount: 2,
      foreignVehicle: false,
      materialDamageOnly: true,
      otherPartyRefused: false,
      emergencyCalled: false,
      policeAttended: false,
      witnessesPresent: true,
      photosTaken: true,
      sketchPrepared: true,
      reportSigned: true,
      insurerNotified: false,
      memoAvailable: true,
    );
    final assessment = AccidentAssessment(
      actionLevel: AccidentActionLevel.electronicReport,
      score: 92,
      emergencyRequired: false,
      eConstatEligible: true,
      paperReportRequired: false,
      declarationDueDate: DateTime(2026, 8, 13),
      items: const [],
      photoSuggestions: const [],
    );

    final summary = assessment.buildShareSummary(
      input: input,
      vehicleLabel: 'Auto principale',
    );

    expect(summary, contains('AUTOCLAIR — DOSSIER ACCIDENT'));
    expect(summary, contains('Nombre de véhicules : 2'));
    expect(summary, contains('ne détermine jamais les responsabilités'));
    expect(summary.toLowerCase(), isNot(contains('nom du tiers')));
    expect(summary.toLowerCase(), isNot(contains('téléphone du tiers')));
    expect(summary.toLowerCase(), isNot(contains('immatriculation du tiers')));
  });

  test('parses a recent stored accident case', () {
    final snapshot = AccidentCaseSnapshot.fromMap({
      'id': 'case-1',
      'occurred_at': '2026-08-06',
      'action_level': 'PAPER_REPORT',
      'readiness_score': 68,
      'insurer_notified': true,
    });

    expect(snapshot.id, 'case-1');
    expect(snapshot.actionLevel, AccidentActionLevel.paperReport);
    expect(snapshot.score, 68);
    expect(snapshot.insurerNotified, isTrue);
  });
}
