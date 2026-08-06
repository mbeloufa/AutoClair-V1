import 'package:autoclair_app/features/theft_assistant/theft_assistant_calculator.dart';
import 'package:autoclair_app/features/theft_assistant/theft_assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incident in progress requires police emergency call', () {
    final assessment = TheftAssistantCalculator.assess(
      profile: _profile(),
      input: _input(incidentInProgress: true),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.actionLevel, TheftActionLevel.emergency);
    expect(assessment.emergencyRequired, isTrue);
    expect(assessment.items.any((item) => item.code == 'EMERGENCY'), isTrue);
  });

  test('missing vehicle requires an impound check before theft report', () {
    final assessment = TheftAssistantCalculator.assess(
      profile: _profile(),
      input: _input(vehicleMissing: true, impoundChecked: false),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.actionLevel, TheftActionLevel.checkImpound);
    final item = assessment.items.firstWhere(
      (element) => element.code == 'IMPOUND',
    );
    expect(item.level, TheftCheckLevel.blocking);
    expect(item.detail, contains('fourrière'));
  });

  test('unknown author allows online complaint and two working days', () {
    final assessment = TheftAssistantCalculator.assess(
      profile: _profile(),
      input: _input(
        vehicleMissing: true,
        impoundChecked: true,
        authorKnown: false,
      ),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.actionLevel, TheftActionLevel.policeReport);
    expect(assessment.onlineComplaintEligible, isTrue);
    expect(assessment.declarationDueDate, DateTime(2026, 8, 10));
    expect(assessment.declarationDueDate.hour, 0);
  });

  test('vandalism uses the general five-working-day minimum', () {
    final assessment = TheftAssistantCalculator.assess(
      profile: _profile(),
      input: _input(
        incidentType: TheftIncidentType.vandalism,
        vehicleMissing: false,
      ),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.declarationDueDate, DateTime(2026, 8, 13));
    final insurer = assessment.items.firstWhere(
      (element) => element.code == 'INSURER',
    );
    expect(insurer.detail, contains('cinq jours ouvrés'));
  });

  test('tracker guidance never recommends personal recovery', () {
    final assessment = TheftAssistantCalculator.assess(
      profile: _profile(trackerAvailable: true),
      input: _input(
        vehicleMissing: true,
        impoundChecked: true,
        policeReported: true,
      ),
      now: DateTime(2026, 8, 6),
    );

    final tracker = assessment.items.firstWhere(
      (element) => element.code == 'TRACKER',
    );
    expect(tracker.detail, contains('forces de l’ordre'));
    expect(tracker.detail, contains('Ne tentez pas de récupérer seul'));
  });

  test('found vehicle requires police and insurer follow-up', () {
    final assessment = TheftAssistantCalculator.assess(
      profile: _profile(),
      input: _input(
        vehicleMissing: false,
        impoundChecked: true,
        policeReported: true,
        insurerNotified: true,
        vehicleFound: true,
      ),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.actionLevel, TheftActionLevel.followUp);
    final found = assessment.items.firstWhere(
      (element) => element.code == 'FOUND',
    );
    expect(found.detail, contains('forces de l’ordre'));
    expect(found.detail, contains('assureur'));
  });
}

TheftAssistantProfile _profile({bool trackerAvailable = false}) {
  return TheftAssistantProfile(
    vehicleId: 'vehicle-1',
    insurerName: '',
    claimPhone: '',
    assistancePhone: '',
    contractReference: '',
    trackerAvailable: trackerAvailable,
    theftCoverageKnown: false,
  );
}

TheftCaseInput _input({
  TheftIncidentType incidentType = TheftIncidentType.vehicleTheft,
  bool incidentInProgress = false,
  bool authorKnown = false,
  bool vehicleMissing = false,
  bool impoundChecked = false,
  bool policeReported = false,
  bool insurerNotified = false,
  bool vehicleFound = false,
}) {
  return TheftCaseInput(
    vehicleId: 'vehicle-1',
    occurredAt: DateTime(2026, 8, 6),
    incidentType: incidentType,
    contextType: TheftContextType.publicRoad,
    incidentInProgress: incidentInProgress,
    authorKnown: authorKnown,
    vehicleMissing: vehicleMissing,
    impoundChecked: impoundChecked,
    policeReported: policeReported,
    complaintReceiptAvailable: false,
    insurerNotified: insurerNotified,
    registrationDocumentStolen: false,
    insuranceDocumentsStolen: false,
    drivingLicenceStolen: false,
    keysAvailableCount: 2,
    photosTaken: false,
    invoicesAvailable: false,
    trackerDeclaredToPolice: false,
    vehicleFound: vehicleFound,
  );
}
