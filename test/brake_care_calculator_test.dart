import 'package:autoclair_app/features/brake_care/brake_care_calculator.dart';
import 'package:autoclair_app/features/brake_care/brake_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BrakeCareProfile profile({
    Map<BrakeCareArea, BrakeCareStatus>? checks,
    bool vehicleCanMoveSafely = true,
    bool brakingAnomaly = false,
    bool steeringInstability = false,
    bool recentImpact = false,
    BrakeCheckContext context = BrakeCheckContext.routine,
  }) {
    return BrakeCareProfile(
      vehicleId: 'vehicle',
      checkedAt: DateTime.now(),
      checkContext: context,
      checks:
          checks ??
          {
            for (final area in BrakeCareArea.values)
              area: BrakeCareStatus.normal,
          },
      vehicleCanMoveSafely: vehicleCanMoveSafely,
      brakingAnomaly: brakingAnomaly,
      steeringInstability: steeringInstability,
      recentImpact: recentImpact,
    );
  }

  test('complete normal brake check remains ready', () {
    final result = BrakeCareCalculator.assess(profile());
    expect(result.level, BrakeCareLevel.ready);
    expect(result.score, 100);
    expect(result.completenessPercent, 100);
  });

  test('unsafe vehicle creates urgent guidance', () {
    final result = BrakeCareCalculator.assess(
      profile(vehicleCanMoveSafely: false),
    );
    expect(result.level, BrakeCareLevel.urgent);
    expect(result.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps brake care under review', () {
    final checks = {
      for (final area in BrakeCareArea.values) area: BrakeCareStatus.normal,
    };
    checks[BrakeCareArea.parkingBrake] = BrakeCareStatus.notChecked;
    final result = BrakeCareCalculator.assess(profile(checks: checks));
    expect(result.level, BrakeCareLevel.review);
    expect(result.score, 100);
    expect(result.completenessPercent, 90);
  });

  test('not applicable point still counts as completed', () {
    final checks = {
      for (final area in BrakeCareArea.values) area: BrakeCareStatus.normal,
    };
    checks[BrakeCareArea.parkingBrake] = BrakeCareStatus.notApplicable;
    final result = BrakeCareCalculator.assess(profile(checks: checks));
    expect(result.level, BrakeCareLevel.ready);
    expect(result.completenessPercent, 100);
  });

  test('braking anomaly remains explicit', () {
    final result = BrakeCareCalculator.assess(profile(brakingAnomaly: true));
    expect(
      result.findings.map((finding) => finding.code),
      contains('BRAKING_ANOMALY'),
    );
    expect(result.level, BrakeCareLevel.review);
  });

  test('urgent pedal concern overrides a high score', () {
    final checks = {
      for (final area in BrakeCareArea.values) area: BrakeCareStatus.normal,
    };
    checks[BrakeCareArea.pedalFeel] = BrakeCareStatus.urgent;
    final result = BrakeCareCalculator.assess(profile(checks: checks));
    expect(result.level, BrakeCareLevel.urgent);
    expect(result.urgentCount, 1);
  });

  test('recent impact requires stability checks', () {
    final checks = {
      for (final area in BrakeCareArea.values) area: BrakeCareStatus.normal,
    };
    checks[BrakeCareArea.directionalStability] = BrakeCareStatus.notChecked;
    final result = BrakeCareCalculator.assess(
      profile(
        checks: checks,
        recentImpact: true,
        context: BrakeCheckContext.afterImpact,
      ),
    );
    expect(
      result.findings.map((finding) => finding.code),
      contains('RECENT_IMPACT_CHECK_INCOMPLETE'),
    );
  });
}
