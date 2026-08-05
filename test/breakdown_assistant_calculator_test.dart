import 'package:autoclair_app/features/breakdown_assistant/breakdown_assistant_calculator.dart';
import 'package:autoclair_app/features/breakdown_assistant/breakdown_assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BreakdownAssessment assess({
    BreakdownLocationType location = BreakdownLocationType.safeParking,
    Set<BreakdownSymptom> symptoms = const {},
    bool safelyParked = true,
    bool vehicleInTrafficLane = false,
    bool injuredPerson = false,
    bool vehicleCanMove = true,
  }) {
    return BreakdownAssistantCalculator.assess(
      BreakdownAssessmentInput(
        locationType: location,
        symptoms: symptoms,
        safelyParked: safelyParked,
        vehicleInTrafficLane: vehicleInTrafficLane,
        injuredPerson: injuredPerson,
        vehicleCanMove: vehicleCanMove,
      ),
    );
  }

  test('injury or fire requires emergency services and forbids driving', () {
    final result = assess(
      symptoms: {BreakdownSymptom.smokeOrFire},
      injuredPerson: true,
    );

    expect(result.actionLevel, BreakdownActionLevel.emergency);
    expect(result.shouldCall112, isTrue);
    expect(result.mayDrive, isFalse);
    expect(
      result.thingsToAvoid,
      contains('N’ouvrez pas le capot en présence de fumée ou de feu.'),
    );
  });

  test(
    'motorway exposure prioritizes evacuation and never uses a triangle',
    () {
      final result = assess(
        location: BreakdownLocationType.motorway,
        safelyParked: false,
        vehicleInTrafficLane: true,
      );

      expect(result.actionLevel, BreakdownActionLevel.motorwaySafety);
      expect(result.shouldCall112, isTrue);
      expect(result.mayDrive, isFalse);
      expect(
        result.thingsToAvoid.join(' '),
        contains('N’installez pas le triangle sur autoroute'),
      );
    },
  );

  test('high-voltage warning requires assistance without user repair', () {
    final result = assess(symptoms: {BreakdownSymptom.highVoltageWarning});

    expect(result.actionLevel, BreakdownActionLevel.stopAndAssistance);
    expect(result.shouldCallAssistance, isTrue);
    expect(result.subcategoryCode, 'BATTERY_ELECTRICAL');
    expect(result.safeChecks.join(' '), contains('câbles orange'));
  });

  test('a no-start case is classified as electrical assistance', () {
    final result = assess(
      symptoms: {BreakdownSymptom.noStart},
      vehicleCanMove: false,
    );

    expect(result.actionLevel, BreakdownActionLevel.assistanceRecommended);
    expect(result.categoryCode, 'REPAIR');
    expect(result.subcategoryCode, 'BATTERY_ELECTRICAL');
  });

  test('noise without critical warning recommends a quick garage check', () {
    final result = assess(symptoms: {BreakdownSymptom.unusualNoise});

    expect(result.actionLevel, BreakdownActionLevel.garageSoon);
    expect(result.shouldCall112, isFalse);
    expect(result.mayDrive, isTrue);
  });
}
