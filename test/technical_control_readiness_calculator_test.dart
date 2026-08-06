import 'package:autoclair_app/features/technical_control_readiness/technical_control_readiness_calculator.dart';
import 'package:autoclair_app/features/technical_control_readiness/technical_control_readiness_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete satisfactory preparation remains ready', () {
    final assessment = TechnicalControlReadinessCalculator.assess(
      _profile(checks: _satisfactoryChecks()),
    );

    expect(assessment.level, TechnicalControlReadinessLevel.ready);
    expect(assessment.score, 100);
    expect(assessment.completenessPercent, 100);
  });

  test('manifest braking problem blocks the preparation', () {
    final checks = _satisfactoryChecks();
    checks[TechnicalControlArea.braking] = TechnicalControlCheckStatus.blocking;
    final assessment = TechnicalControlReadinessCalculator.assess(
      _profile(checks: checks),
    );

    expect(assessment.level, TechnicalControlReadinessLevel.blocked);
    expect(assessment.blockingCount, 1);
  });

  test('vehicle declared unsafe to move creates priority guidance', () {
    final assessment = TechnicalControlReadinessCalculator.assess(
      _profile(checks: _satisfactoryChecks(), vehicleCanMoveSafely: false),
    );

    expect(assessment.level, TechnicalControlReadinessLevel.blocked);
    expect(
      assessment.findings.any((finding) => finding.code == 'UNSAFE_TO_MOVE'),
      isTrue,
    );
  });

  test('unchecked points reduce completeness without hiding score', () {
    final checks = _satisfactoryChecks();
    checks[TechnicalControlArea.exhaustAndNoise] =
        TechnicalControlCheckStatus.notChecked;
    final assessment = TechnicalControlReadinessCalculator.assess(
      _profile(checks: checks),
    );

    expect(assessment.completenessPercent, lessThan(100));
    expect(assessment.score, 100);
    expect(assessment.level, TechnicalControlReadinessLevel.review);
  });

  test('warning light creates an explicit recommendation', () {
    final assessment = TechnicalControlReadinessCalculator.assess(
      _profile(checks: _satisfactoryChecks(), warningLightOn: true),
    );

    expect(
      assessment.findings.any((finding) => finding.code == 'WARNING_LIGHT'),
      isTrue,
    );
  });

  test('counter visit with incomplete checklist is explicit', () {
    final checks = _satisfactoryChecks();
    checks[TechnicalControlArea.bodyAndDoors] =
        TechnicalControlCheckStatus.notChecked;
    final assessment = TechnicalControlReadinessCalculator.assess(
      _profile(
        context: TechnicalControlVisitContext.counterVisit,
        checks: checks,
      ),
    );

    expect(
      assessment.findings.any(
        (finding) => finding.code == 'COUNTER_VISIT_INCOMPLETE',
      ),
      isTrue,
    );
  });
}

TechnicalControlReadinessProfile _profile({
  TechnicalControlVisitContext context = TechnicalControlVisitContext.periodic,
  required Map<TechnicalControlArea, TechnicalControlCheckStatus> checks,
  bool vehicleCanMoveSafely = true,
  bool warningLightOn = false,
}) => TechnicalControlReadinessProfile(
  vehicleId: '00000000-0000-0000-0000-000000000001',
  plannedDate: DateTime.now().add(const Duration(days: 5)),
  visitContext: context,
  checks: checks,
  vehicleCanMoveSafely: vehicleCanMoveSafely,
  warningLightOn: warningLightOn,
);

Map<TechnicalControlArea, TechnicalControlCheckStatus> _satisfactoryChecks() =>
    {
      for (final area in TechnicalControlArea.values)
        area: TechnicalControlCheckStatus.satisfactory,
    };
