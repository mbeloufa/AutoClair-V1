import 'package:autoclair_app/features/tire_care/tire_care_calculator.dart';
import 'package:autoclair_app/features/tire_care/tire_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete satisfactory tire check remains ready', () {
    final result = TireCareCalculator.assess(_profile());
    expect(result.level, TireCareLevel.ready);
    expect(result.score, 100);
    expect(result.completenessPercent, 100);
  });

  test('unsafe vehicle creates urgent guidance', () {
    final result = TireCareCalculator.assess(
      _profile(vehicleCanMoveSafely: false),
    );
    expect(result.level, TireCareLevel.urgent);
    expect(result.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps tire care under review', () {
    final checks = _goodChecks();
    checks[TireCareArea.spareOrRepairKit] = TireCareStatus.notChecked;
    final result = TireCareCalculator.assess(_profile(checks: checks));
    expect(result.level, TireCareLevel.review);
    expect(result.score, 100);
    expect(result.completenessPercent, lessThan(100));
  });

  test('urgent sidewall concern overrides a high score', () {
    final checks = _goodChecks();
    checks[TireCareArea.sidewalls] = TireCareStatus.urgent;
    final result = TireCareCalculator.assess(_profile(checks: checks));
    expect(result.level, TireCareLevel.urgent);
    expect(result.urgentCount, 1);
  });

  test('vibration remains an explicit recommendation', () {
    final result = TireCareCalculator.assess(
      _profile(vibrationOrPulling: true),
    );
    expect(result.level, TireCareLevel.review);
    expect(
      result.findings.any((finding) => finding.code == 'VIBRATION_OR_PULLING'),
      isTrue,
    );
  });

  test('seasonal change requires the suitability point', () {
    final checks = _goodChecks();
    checks[TireCareArea.seasonalSuitability] = TireCareStatus.monitor;
    final result = TireCareCalculator.assess(
      _profile(checkContext: TireCheckContext.seasonalChange, checks: checks),
    );
    expect(result.level, TireCareLevel.review);
    expect(
      result.findings.any((finding) => finding.code == 'SEASONAL_SUITABILITY'),
      isTrue,
    );
  });
}

TireCareProfile _profile({
  TireCheckContext checkContext = TireCheckContext.routine,
  Map<TireCareArea, TireCareStatus>? checks,
  bool vehicleCanMoveSafely = true,
  bool vibrationOrPulling = false,
  bool recentImpact = false,
}) {
  return TireCareProfile(
    vehicleId: 'vehicle',
    checkedAt: DateTime.now(),
    checkContext: checkContext,
    checks: checks ?? _goodChecks(),
    vehicleCanMoveSafely: vehicleCanMoveSafely,
    vibrationOrPulling: vibrationOrPulling,
    recentImpact: recentImpact,
  );
}

Map<TireCareArea, TireCareStatus> _goodChecks() => {
  for (final area in TireCareArea.values) area: TireCareStatus.good,
};
