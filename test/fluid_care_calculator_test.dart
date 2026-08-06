import 'package:autoclair_app/features/fluid_care/fluid_care_calculator.dart';
import 'package:autoclair_app/features/fluid_care/fluid_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete normal fluid check remains ready', () {
    final assessment = FluidCareCalculator.assess(_profile());

    expect(assessment.level, FluidCareLevel.ready);
    expect(assessment.score, 100);
    expect(assessment.completenessPercent, 100);
  });

  test('unsafe vehicle creates urgent guidance', () {
    final assessment = FluidCareCalculator.assess(
      _profile(vehicleCanMoveSafely: false),
    );

    expect(assessment.level, FluidCareLevel.urgent);
    expect(assessment.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps fluid care under review', () {
    final checks = _normalChecks();
    checks[FluidCareArea.professionalCheckPlan] = FluidCareStatus.notChecked;

    final assessment = FluidCareCalculator.assess(_profile(checks: checks));

    expect(assessment.level, FluidCareLevel.review);
    expect(assessment.completenessPercent, 90);
    expect(assessment.score, 100);
  });

  test('not applicable point still counts as completed', () {
    final checks = _normalChecks();
    checks[FluidCareArea.additiveOrAdBlue] = FluidCareStatus.notApplicable;

    final assessment = FluidCareCalculator.assess(
      _profile(checks: checks, electrifiedVehicle: true),
    );

    expect(assessment.level, FluidCareLevel.ready);
    expect(assessment.completenessPercent, 100);
  });

  test('visible leak remains an explicit recommendation', () {
    final assessment = FluidCareCalculator.assess(
      _profile(visibleLeakObserved: true),
    );

    expect(assessment.level, FluidCareLevel.review);
    expect(
      assessment.findings.any(
        (finding) => finding.code == 'VISIBLE_LEAK_OBSERVED',
      ),
      isTrue,
    );
  });

  test('urgent cooling concern overrides a high score', () {
    final checks = _normalChecks();
    checks[FluidCareArea.coolingSystem] = FluidCareStatus.urgent;

    final assessment = FluidCareCalculator.assess(_profile(checks: checks));

    expect(assessment.level, FluidCareLevel.urgent);
    expect(assessment.urgentCount, 1);
  });
}

FluidCareProfile _profile({
  Map<FluidCareArea, FluidCareStatus>? checks,
  bool vehicleCanMoveSafely = true,
  bool visibleLeakObserved = false,
  bool warningMessageOn = false,
  bool electrifiedVehicle = false,
}) {
  return FluidCareProfile(
    vehicleId: 'vehicle',
    checkedAt: DateTime.now(),
    checkContext: FluidCheckContext.routine,
    checks: checks ?? _normalChecks(),
    vehicleCanMoveSafely: vehicleCanMoveSafely,
    visibleLeakObserved: visibleLeakObserved,
    warningMessageOn: warningMessageOn,
    electrifiedVehicle: electrifiedVehicle,
  );
}

Map<FluidCareArea, FluidCareStatus> _normalChecks() => {
  for (final area in FluidCareArea.values) area: FluidCareStatus.normal,
};
