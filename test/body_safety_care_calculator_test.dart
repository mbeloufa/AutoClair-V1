import 'package:autoclair_app/features/body_safety_care/body_safety_care_calculator.dart';
import 'package:autoclair_app/features/body_safety_care/body_safety_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BodySafetyCareProfile profile({
    Map<BodySafetyCareArea, BodySafetyCareStatus>? checks,
    bool vehicleCanMoveSafely = true,
    bool closureConcern = false,
    bool restraintConcern = false,
    bool recentImpact = false,
    BodySafetyCheckContext context = BodySafetyCheckContext.routine,
  }) {
    return BodySafetyCareProfile(
      vehicleId: 'vehicle',
      checkedAt: DateTime.now(),
      checkContext: context,
      checks:
          checks ??
          {
            for (final area in BodySafetyCareArea.values)
              area: BodySafetyCareStatus.normal,
          },
      vehicleCanMoveSafely: vehicleCanMoveSafely,
      closureConcern: closureConcern,
      restraintConcern: restraintConcern,
      recentImpact: recentImpact,
    );
  }

  test('complete normal body safety check remains ready', () {
    final result = BodySafetyCareCalculator.assess(profile());
    expect(result.level, BodySafetyCareLevel.ready);
    expect(result.score, 100);
    expect(result.completenessPercent, 100);
  });

  test('unsafe vehicle creates urgent guidance', () {
    final result = BodySafetyCareCalculator.assess(
      profile(vehicleCanMoveSafely: false),
    );
    expect(result.level, BodySafetyCareLevel.urgent);
    expect(result.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps body safety care under review', () {
    final checks = {
      for (final area in BodySafetyCareArea.values)
        area: BodySafetyCareStatus.normal,
    }..[BodySafetyCareArea.hornAndControls] = BodySafetyCareStatus.notChecked;
    final result = BodySafetyCareCalculator.assess(profile(checks: checks));
    expect(result.level, BodySafetyCareLevel.review);
    expect(result.completenessPercent, 90);
  });

  test('not applicable point still counts as completed', () {
    final checks =
        {
            for (final area in BodySafetyCareArea.values)
              area: BodySafetyCareStatus.normal,
          }
          ..[BodySafetyCareArea.trunkAndTailgate] =
              BodySafetyCareStatus.notApplicable;
    final result = BodySafetyCareCalculator.assess(profile(checks: checks));
    expect(result.completenessPercent, 100);
  });

  test('closure concern remains explicit', () {
    final result = BodySafetyCareCalculator.assess(
      profile(closureConcern: true),
    );
    expect(
      result.findings.any((item) => item.code == 'CLOSURE_CONCERN'),
      isTrue,
    );
    expect(result.level, BodySafetyCareLevel.review);
  });

  test('urgent hood concern overrides a high score', () {
    final checks = {
      for (final area in BodySafetyCareArea.values)
        area: BodySafetyCareStatus.normal,
    }..[BodySafetyCareArea.hoodClosure] = BodySafetyCareStatus.urgent;
    final result = BodySafetyCareCalculator.assess(profile(checks: checks));
    expect(result.level, BodySafetyCareLevel.urgent);
    expect(result.urgentCount, 1);
  });

  test('recent impact requires body and closure checks', () {
    final checks =
        {
            for (final area in BodySafetyCareArea.values)
              area: BodySafetyCareStatus.normal,
          }
          ..[BodySafetyCareArea.bodyFixingsAndSharpEdges] =
              BodySafetyCareStatus.notChecked;
    final result = BodySafetyCareCalculator.assess(
      profile(checks: checks, recentImpact: true),
    );
    expect(
      result.findings.any(
        (item) => item.code == 'RECENT_IMPACT_CHECK_INCOMPLETE',
      ),
      isTrue,
    );
  });
}
