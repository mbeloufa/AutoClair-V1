import 'package:autoclair_app/features/theft_assistant/theft_assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes insurer phone numbers for direct calling', () {
    const profile = TheftAssistantProfile(
      vehicleId: 'vehicle-1',
      insurerName: 'Assureur test',
      claimPhone: '01 23 45 67 89',
      assistancePhone: '+33 (0)1 40 00 00 00',
      contractReference: 'VOL-123',
      trackerAvailable: true,
      theftCoverageKnown: true,
    );

    expect(profile.callableClaimPhone, '0123456789');
    expect(profile.callableAssistancePhone, '+330140000000');
    expect(profile.validate, returnsNormally);
  });

  test('rejects an invalid number of available keys', () {
    final input = _input(keysAvailableCount: 5);

    expect(input.validate, throwsFormatException);
  });

  test('summary contains facts but no author identity or exact location', () {
    final input = _input(
      incidentType: TheftIncidentType.vehicleTheft,
      contextType: TheftContextType.parking,
      vehicleMissing: true,
      impoundChecked: true,
      policeReported: true,
      complaintReceiptAvailable: true,
    );
    final assessment = TheftAssessment(
      actionLevel: TheftActionLevel.insurerDeclaration,
      score: 84,
      emergencyRequired: false,
      onlineComplaintEligible: true,
      declarationDueDate: DateTime(2026, 8, 10),
      items: const [],
      evidenceSuggestions: const [],
    );

    final summary = assessment.buildShareSummary(
      input: input,
      vehicleLabel: 'Auto principale',
    );

    expect(summary, contains('AUTOCLAIR — DOSSIER VOL OU DÉGRADATION'));
    expect(summary, contains('Fourrière vérifiée : oui'));
    expect(summary, contains('contrat prioritaire'));
    expect(summary.toLowerCase(), isNot(contains('nom de l’auteur')));
    expect(summary.toLowerCase(), isNot(contains('adresse exacte')));
    expect(summary.toLowerCase(), isNot(contains('latitude')));
    expect(summary.toLowerCase(), isNot(contains('longitude')));
  });

  test('parses a recent stored theft case', () {
    final snapshot = TheftCaseSnapshot.fromMap({
      'id': 'case-1',
      'occurred_at': '2026-08-06',
      'incident_type': 'PLATE_THEFT',
      'action_level': 'POLICE_REPORT',
      'readiness_score': 67,
      'insurer_notified': false,
    });

    expect(snapshot.id, 'case-1');
    expect(snapshot.incidentType, TheftIncidentType.plateTheft);
    expect(snapshot.actionLevel, TheftActionLevel.policeReport);
    expect(snapshot.score, 67);
  });
}

TheftCaseInput _input({
  TheftIncidentType incidentType = TheftIncidentType.vehicleTheft,
  TheftContextType contextType = TheftContextType.publicRoad,
  bool vehicleMissing = false,
  bool impoundChecked = false,
  bool policeReported = false,
  bool complaintReceiptAvailable = false,
  int keysAvailableCount = 2,
}) {
  return TheftCaseInput(
    vehicleId: 'vehicle-1',
    occurredAt: DateTime(2026, 8, 6),
    incidentType: incidentType,
    contextType: contextType,
    incidentInProgress: false,
    authorKnown: false,
    vehicleMissing: vehicleMissing,
    impoundChecked: impoundChecked,
    policeReported: policeReported,
    complaintReceiptAvailable: complaintReceiptAvailable,
    insurerNotified: false,
    registrationDocumentStolen: false,
    insuranceDocumentsStolen: false,
    drivingLicenceStolen: false,
    keysAvailableCount: keysAvailableCount,
    photosTaken: false,
    invoicesAvailable: false,
    trackerDeclaredToPolice: false,
    vehicleFound: false,
  );
}
