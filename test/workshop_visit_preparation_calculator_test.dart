import 'package:autoclair_app/features/workshop_visit/workshop_visit_preparation_calculator.dart';
import 'package:autoclair_app/features/workshop_visit/workshop_visit_preparation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete preparation remains ready', () {
    final result = WorkshopVisitPreparationCalculator.assess(_profile());

    expect(result.level, WorkshopPreparationLevel.ready);
    expect(result.score, 100);
    expect(result.completenessPercent, 100);
  });

  test('unsafe vehicle creates urgent guidance', () {
    final result = WorkshopVisitPreparationCalculator.assess(
      _profile(vehicleCanMoveSafely: false),
    );

    expect(result.level, WorkshopPreparationLevel.urgent);
    expect(result.urgentCount, greaterThan(0));
    expect(result.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps the preparation under review', () {
    final checks = _readyChecks();
    checks[WorkshopPreparationArea.documents] =
        WorkshopPreparationStatus.notChecked;
    final result = WorkshopVisitPreparationCalculator.assess(
      _profile(checks: checks),
    );

    expect(result.level, WorkshopPreparationLevel.review);
    expect(result.completenessPercent, lessThan(100));
    expect(result.score, 100);
  });

  test('warning light remains an explicit recommendation', () {
    final result = WorkshopVisitPreparationCalculator.assess(
      _profile(reason: WorkshopVisitReason.warningLight, warningLightOn: true),
    );

    expect(result.findings.any((item) => item.code == 'WARNING_LIGHT'), isTrue);
    expect(result.level, WorkshopPreparationLevel.review);
  });

  test('symptom reason requires prepared occurrence conditions', () {
    final checks = _readyChecks();
    checks[WorkshopPreparationArea.symptomConditions] =
        WorkshopPreparationStatus.toPrepare;
    final result = WorkshopVisitPreparationCalculator.assess(
      _profile(reason: WorkshopVisitReason.noiseOrVibration, checks: checks),
    );

    expect(
      result.findings.any((item) => item.code == 'SYMPTOM_CONTEXT'),
      isTrue,
    );
    expect(result.level, isNot(WorkshopPreparationLevel.ready));
  });

  test('urgent safety area overrides a high preparation score', () {
    final checks = _readyChecks();
    checks[WorkshopPreparationArea.drivingSafety] =
        WorkshopPreparationStatus.urgent;
    final result = WorkshopVisitPreparationCalculator.assess(
      _profile(checks: checks),
    );

    expect(result.level, WorkshopPreparationLevel.urgent);
    expect(result.urgentCount, 1);
  });
}

WorkshopVisitPreparationProfile _profile({
  WorkshopVisitReason reason = WorkshopVisitReason.routineMaintenance,
  Map<WorkshopPreparationArea, WorkshopPreparationStatus>? checks,
  bool vehicleCanMoveSafely = true,
  bool warningLightOn = false,
}) {
  return WorkshopVisitPreparationProfile(
    vehicleId: 'vehicle',
    plannedDate: DateTime.now().add(const Duration(days: 5)),
    visitReason: reason,
    checks: checks ?? _readyChecks(),
    vehicleCanMoveSafely: vehicleCanMoveSafely,
    warningLightOn: warningLightOn,
  );
}

Map<WorkshopPreparationArea, WorkshopPreparationStatus> _readyChecks() => {
  for (final area in WorkshopPreparationArea.values)
    area: WorkshopPreparationStatus.ready,
};
