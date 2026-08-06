import 'package:autoclair_app/features/visibility_care/visibility_care_calculator.dart';
import 'package:autoclair_app/features/visibility_care/visibility_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VisibilityCareProfile profile({
    Map<VisibilityCareArea, VisibilityCareStatus>? checks,
    bool vehicleCanMoveSafely = true,
    bool majorVisibilityObstruction = false,
    bool essentialLightFailure = false,
    bool badWeatherExpected = false,
    VisibilityCheckContext context = VisibilityCheckContext.routine,
  }) {
    return VisibilityCareProfile(
      vehicleId: 'vehicle',
      checkedAt: DateTime.now(),
      checkContext: context,
      checks:
          checks ??
          {
            for (final area in VisibilityCareArea.values)
              area: VisibilityCareStatus.normal,
          },
      vehicleCanMoveSafely: vehicleCanMoveSafely,
      majorVisibilityObstruction: majorVisibilityObstruction,
      essentialLightFailure: essentialLightFailure,
      badWeatherExpected: badWeatherExpected,
    );
  }

  test('complete normal visibility check remains ready', () {
    final result = VisibilityCareCalculator.assess(profile());
    expect(result.level, VisibilityCareLevel.ready);
    expect(result.score, 100);
    expect(result.completenessPercent, 100);
  });

  test('unsafe vehicle creates urgent guidance', () {
    final result = VisibilityCareCalculator.assess(
      profile(vehicleCanMoveSafely: false),
    );
    expect(result.level, VisibilityCareLevel.urgent);
    expect(result.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps visibility care under review', () {
    final checks = {
      for (final area in VisibilityCareArea.values)
        area: VisibilityCareStatus.normal,
    };
    checks[VisibilityCareArea.mirrors] = VisibilityCareStatus.notChecked;
    final result = VisibilityCareCalculator.assess(profile(checks: checks));
    expect(result.level, VisibilityCareLevel.review);
    expect(result.score, 100);
    expect(result.completenessPercent, 90);
  });

  test('not applicable point still counts as completed', () {
    final checks = {
      for (final area in VisibilityCareArea.values)
        area: VisibilityCareStatus.normal,
    };
    checks[VisibilityCareArea.fogAndReversingLights] =
        VisibilityCareStatus.notApplicable;
    final result = VisibilityCareCalculator.assess(profile(checks: checks));
    expect(result.level, VisibilityCareLevel.ready);
    expect(result.completenessPercent, 100);
  });

  test('major visibility obstruction remains explicit', () {
    final result = VisibilityCareCalculator.assess(
      profile(majorVisibilityObstruction: true),
    );
    expect(
      result.findings.map((finding) => finding.code),
      contains('MAJOR_VISIBILITY_OBSTRUCTION'),
    );
    expect(result.level, VisibilityCareLevel.review);
  });

  test('urgent windshield concern overrides a high score', () {
    final checks = {
      for (final area in VisibilityCareArea.values)
        area: VisibilityCareStatus.normal,
    };
    checks[VisibilityCareArea.windshieldAndGlass] = VisibilityCareStatus.urgent;
    final result = VisibilityCareCalculator.assess(profile(checks: checks));
    expect(result.level, VisibilityCareLevel.urgent);
    expect(result.urgentCount, 1);
  });

  test('bad weather requires visibility equipment checks', () {
    final checks = {
      for (final area in VisibilityCareArea.values)
        area: VisibilityCareStatus.normal,
    };
    checks[VisibilityCareArea.wipers] = VisibilityCareStatus.notChecked;
    final result = VisibilityCareCalculator.assess(
      profile(
        checks: checks,
        badWeatherExpected: true,
        context: VisibilityCheckContext.badWeather,
      ),
    );
    expect(
      result.findings.map((finding) => finding.code),
      contains('BAD_WEATHER_CHECK_INCOMPLETE'),
    );
  });
}
