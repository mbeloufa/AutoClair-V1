import 'package:autoclair_app/features/battery_care/battery_care_calculator.dart';
import 'package:autoclair_app/features/battery_care/battery_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete normal battery check remains ready', () {
    final assessment = BatteryCareCalculator.assess(_profile());

    expect(assessment.level, BatteryCareLevel.ready);
    expect(assessment.score, 100);
    expect(assessment.completenessPercent, 100);
  });

  test('unsafe vehicle creates urgent guidance', () {
    final assessment = BatteryCareCalculator.assess(
      _profile(vehicleCanMoveSafely: false),
    );

    expect(assessment.level, BatteryCareLevel.urgent);
    expect(assessment.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps battery care under review', () {
    final checks = _normalChecks();
    checks[BatteryCareArea.professionalTest] = BatteryCareStatus.notChecked;

    final assessment = BatteryCareCalculator.assess(_profile(checks: checks));

    expect(assessment.level, BatteryCareLevel.review);
    expect(assessment.completenessPercent, 90);
    expect(assessment.score, 100);
  });

  test('difficult start remains an explicit recommendation', () {
    final assessment = BatteryCareCalculator.assess(
      _profile(difficultStart: true),
    );

    expect(assessment.level, BatteryCareLevel.review);
    expect(
      assessment.findings.any((finding) => finding.code == 'DIFFICULT_START'),
      isTrue,
    );
  });

  test('urgent visible connection concern overrides a high score', () {
    final checks = _normalChecks();
    checks[BatteryCareArea.visibleConnections] = BatteryCareStatus.urgent;

    final assessment = BatteryCareCalculator.assess(_profile(checks: checks));

    expect(assessment.level, BatteryCareLevel.urgent);
    expect(assessment.urgentCount, 1);
  });

  test('long parking requires the preparation point', () {
    final checks = _normalChecks();
    checks[BatteryCareArea.longParkingPreparation] = BatteryCareStatus.monitor;

    final assessment = BatteryCareCalculator.assess(
      _profile(checks: checks, parkedMoreThan14Days: true),
    );

    expect(assessment.level, BatteryCareLevel.review);
    expect(
      assessment.findings.any(
        (finding) => finding.code == 'LONG_PARKING_PREPARATION',
      ),
      isTrue,
    );
  });
}

BatteryCareProfile _profile({
  Map<BatteryCareArea, BatteryCareStatus>? checks,
  bool vehicleCanMoveSafely = true,
  bool difficultStart = false,
  bool recentDischarge = false,
  bool parkedMoreThan14Days = false,
}) {
  return BatteryCareProfile(
    vehicleId: 'vehicle',
    checkedAt: DateTime.now(),
    checkContext: BatteryCheckContext.routine,
    checks: checks ?? _normalChecks(),
    vehicleCanMoveSafely: vehicleCanMoveSafely,
    difficultStart: difficultStart,
    recentDischarge: recentDischarge,
    parkedMoreThan14Days: parkedMoreThan14Days,
  );
}

Map<BatteryCareArea, BatteryCareStatus> _normalChecks() => {
  for (final area in BatteryCareArea.values) area: BatteryCareStatus.normal,
};
