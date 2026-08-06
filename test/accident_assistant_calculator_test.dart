import 'package:autoclair_app/features/accident_assistant/accident_assistant_calculator.dart';
import 'package:autoclair_app/features/accident_assistant/accident_assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('injury requires emergency services and a paper report', () {
    final assessment = AccidentAssistantCalculator.assess(
      input: _input(injured: true, materialDamageOnly: false),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.actionLevel, AccidentActionLevel.emergency);
    expect(assessment.emergencyRequired, isTrue);
    expect(assessment.paperReportRequired, isTrue);
    expect(assessment.eConstatEligible, isFalse);
    expect(
      assessment.items.any((item) => item.code == 'INJURED_PERSON'),
      isTrue,
    );
  });

  test('one or two French vehicles with material damage allow e-constat', () {
    final assessment = AccidentAssistantCalculator.assess(
      input: _input(
        vehicleCount: 2,
        photosTaken: true,
        sketchPrepared: true,
        reportSigned: true,
      ),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.actionLevel, AccidentActionLevel.electronicReport);
    expect(assessment.eConstatEligible, isTrue);
    expect(assessment.paperReportRequired, isFalse);
  });

  test('foreign or multi-vehicle accident requires a paper report', () {
    final foreign = AccidentAssistantCalculator.assess(
      input: _input(foreignVehicle: true),
      now: DateTime(2026, 8, 6),
    );
    final multiple = AccidentAssistantCalculator.assess(
      input: _input(vehicleCount: 3),
      now: DateTime(2026, 8, 6),
    );

    expect(foreign.actionLevel, AccidentActionLevel.paperReport);
    expect(foreign.eConstatEligible, isFalse);
    expect(multiple.actionLevel, AccidentActionLevel.paperReport);
    expect(multiple.paperReportRequired, isTrue);
  });

  test(
    'refusal to sign keeps facts separate and requires insurer follow-up',
    () {
      final assessment = AccidentAssistantCalculator.assess(
        input: _input(otherPartyRefused: true),
        now: DateTime(2026, 8, 6),
      );

      expect(assessment.actionLevel, AccidentActionLevel.paperReport);
      expect(assessment.items.any((item) => item.code == 'REFUSAL'), isTrue);
    },
  );

  test('adds five working days across a weekend', () {
    final assessment = AccidentAssistantCalculator.assess(
      input: _input(occurredAt: DateTime(2026, 8, 6)),
      now: DateTime(2026, 8, 6),
    );

    expect(assessment.declarationDueDate, DateTime(2026, 8, 13));
    expect(assessment.declarationDueDate.hour, 0);
  });

  test('motorway guidance never recommends a triangle', () {
    final assessment = AccidentAssistantCalculator.assess(
      input: _input(locationType: AccidentLocationType.motorway),
      now: DateTime(2026, 8, 6),
    );

    final motorway = assessment.items.firstWhere(
      (item) => item.code == 'MOTORWAY',
    );
    expect(motorway.detail, contains('derrière la glissière'));
    expect(motorway.detail, contains('n’installez pas de triangle'));
  });
}

AccidentCaseInput _input({
  DateTime? occurredAt,
  AccidentLocationType locationType = AccidentLocationType.urban,
  bool injured = false,
  bool immediateDanger = false,
  int vehicleCount = 2,
  bool foreignVehicle = false,
  bool materialDamageOnly = true,
  bool otherPartyRefused = false,
  bool photosTaken = false,
  bool sketchPrepared = false,
  bool reportSigned = false,
}) {
  return AccidentCaseInput(
    vehicleId: 'vehicle-1',
    occurredAt: occurredAt ?? DateTime(2026, 8, 6),
    locationType: locationType,
    injured: injured,
    immediateDanger: immediateDanger,
    vehicleCount: vehicleCount,
    foreignVehicle: foreignVehicle,
    materialDamageOnly: materialDamageOnly,
    otherPartyRefused: otherPartyRefused,
    emergencyCalled: false,
    policeAttended: false,
    witnessesPresent: false,
    photosTaken: photosTaken,
    sketchPrepared: sketchPrepared,
    reportSigned: reportSigned,
    insurerNotified: false,
    memoAvailable: true,
  );
}
