import 'package:autoclair_app/features/vehicle_storage/vehicle_storage_calculator.dart';
import 'package:autoclair_app/features/vehicle_storage/vehicle_storage_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepared short pause remains ready', () {
    final assessment = VehicleStorageCalculator.assess(
      _profile(
        checks: {
          for (final area in VehicleStorageArea.values)
            area: area == VehicleStorageArea.tractionBattery
                ? VehicleStorageStatus.notApplicable
                : VehicleStorageStatus.ready,
        },
      ),
    );

    expect(assessment.level, VehicleStorageLevel.ready);
    expect(assessment.score, 100);
    expect(assessment.completenessPercent, 100);
  });

  test('blocking brakes on restart prevents a ready status', () {
    final checks = _readyChecks();
    checks[VehicleStorageArea.parkingAndBrakes] = VehicleStorageStatus.blocking;
    final assessment = VehicleStorageCalculator.assess(
      _profile(scenario: VehicleStorageScenario.restart, checks: checks),
    );

    expect(assessment.level, VehicleStorageLevel.blocked);
    expect(assessment.blockingCount, 1);
  });

  test('long storage without prepared twelve volt battery is explicit', () {
    final checks = _readyChecks();
    checks[VehicleStorageArea.twelveVoltBattery] =
        VehicleStorageStatus.attention;
    final assessment = VehicleStorageCalculator.assess(
      _profile(plannedWeeks: 24, checks: checks),
    );

    expect(
      assessment.findings.any((finding) => finding.code == 'LONG_STORAGE_12V'),
      isTrue,
    );
  });

  test('electrified vehicle requires traction battery preparation', () {
    final checks = _readyChecks(electricOrHybrid: true);
    checks[VehicleStorageArea.tractionBattery] = VehicleStorageStatus.attention;
    final assessment = VehicleStorageCalculator.assess(
      _profile(electricOrHybrid: true, checks: checks),
    );

    expect(
      assessment.findings.any((finding) => finding.code == 'TRACTION_BATTERY'),
      isTrue,
    );
  });

  test('unchecked points reduce completeness without hiding score', () {
    final checks = {
      for (final area in VehicleStorageArea.values)
        area: area == VehicleStorageArea.tractionBattery
            ? VehicleStorageStatus.notApplicable
            : VehicleStorageStatus.notChecked,
    };
    checks[VehicleStorageArea.cleanAndDry] = VehicleStorageStatus.ready;
    final assessment = VehicleStorageCalculator.assess(
      _profile(checks: checks),
    );

    expect(assessment.completenessPercent, 10);
    expect(assessment.score, 100);
    expect(assessment.level, VehicleStorageLevel.review);
  });

  test('outdoor humid storage creates a protection recommendation', () {
    final checks = _readyChecks();
    checks[VehicleStorageArea.ventilationAndProtection] =
        VehicleStorageStatus.attention;
    final assessment = VehicleStorageCalculator.assess(
      _profile(checks: checks, outdoorStorage: true, humidEnvironment: true),
    );

    expect(
      assessment.findings.any(
        (finding) => finding.code == 'ENVIRONMENT_PROTECTION',
      ),
      isTrue,
    );
  });
}

Map<VehicleStorageArea, VehicleStorageStatus> _readyChecks({
  bool electricOrHybrid = false,
}) => {
  for (final area in VehicleStorageArea.values)
    area: area == VehicleStorageArea.tractionBattery
        ? (electricOrHybrid
              ? VehicleStorageStatus.ready
              : VehicleStorageStatus.notApplicable)
        : VehicleStorageStatus.ready,
};

VehicleStorageProfile _profile({
  VehicleStorageScenario scenario = VehicleStorageScenario.shortPause,
  int plannedWeeks = 4,
  Map<VehicleStorageArea, VehicleStorageStatus>? checks,
  bool electricOrHybrid = false,
  bool outdoorStorage = false,
  bool humidEnvironment = false,
}) {
  return VehicleStorageProfile(
    vehicleId: '11111111-1111-1111-1111-111111111111',
    plannedStartDate: DateTime.now().add(const Duration(days: 14)),
    plannedWeeks: plannedWeeks,
    scenario: scenario,
    checks: checks ?? _readyChecks(electricOrHybrid: electricOrHybrid),
    electricOrHybrid: electricOrHybrid,
    outdoorStorage: outdoorStorage,
    humidEnvironment: humidEnvironment,
  );
}
