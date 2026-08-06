import 'package:autoclair_app/features/lease_return/lease_return_calculator.dart';
import 'package:autoclair_app/features/lease_return/lease_return_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LeaseReturnProfile profile({
    Map<LeaseReturnArea, LeaseReturnStatus>? checks,
    bool vehicleCanMoveSafely = true,
    bool contractInstructionsAvailable = true,
    bool allKeysAndAccessoriesAvailable = true,
    bool warningOrMechanicalConcern = false,
    LeaseReturnContext context = LeaseReturnContext.endOfContract,
  }) {
    return LeaseReturnProfile(
      vehicleId: 'vehicle',
      preparedAt: DateTime.now(),
      preparationContext: context,
      checks:
          checks ??
          {
            for (final area in LeaseReturnArea.values)
              area: LeaseReturnStatus.ready,
          },
      vehicleCanMoveSafely: vehicleCanMoveSafely,
      contractInstructionsAvailable: contractInstructionsAvailable,
      allKeysAndAccessoriesAvailable: allKeysAndAccessoriesAvailable,
      warningOrMechanicalConcern: warningOrMechanicalConcern,
    );
  }

  test('complete lease return preparation remains ready', () {
    final result = LeaseReturnCalculator.assess(profile());
    expect(result.level, LeaseReturnLevel.ready);
    expect(result.score, 100);
    expect(result.completenessPercent, 100);
  });

  test('unsafe vehicle creates priority guidance', () {
    final result = LeaseReturnCalculator.assess(
      profile(vehicleCanMoveSafely: false),
    );
    expect(result.level, LeaseReturnLevel.urgent);
    expect(result.findings.first.code, 'UNSAFE_TO_MOVE');
  });

  test('unchecked point keeps preparation under review', () {
    final checks = {
      for (final area in LeaseReturnArea.values) area: LeaseReturnStatus.ready,
    }..[LeaseReturnArea.returnTiming] = LeaseReturnStatus.notChecked;
    final result = LeaseReturnCalculator.assess(profile(checks: checks));
    expect(result.level, LeaseReturnLevel.review);
    expect(result.completenessPercent, 90);
  });

  test('not applicable point counts as prepared', () {
    final checks = {
      for (final area in LeaseReturnArea.values) area: LeaseReturnStatus.ready,
    }..[LeaseReturnArea.keysAndAccessories] = LeaseReturnStatus.notApplicable;
    final result = LeaseReturnCalculator.assess(profile(checks: checks));
    expect(result.completenessPercent, 100);
  });

  test('missing contract instructions remain explicit', () {
    final result = LeaseReturnCalculator.assess(
      profile(contractInstructionsAvailable: false),
    );
    expect(
      result.findings.any(
        (item) => item.code == 'CONTRACT_INSTRUCTIONS_MISSING',
      ),
      isTrue,
    );
    expect(result.level, LeaseReturnLevel.review);
  });

  test('priority warning concern overrides a high score', () {
    final checks =
        {
            for (final area in LeaseReturnArea.values)
              area: LeaseReturnStatus.ready,
          }
          ..[LeaseReturnArea.warningLightsAndMechanical] =
              LeaseReturnStatus.priority;
    final result = LeaseReturnCalculator.assess(profile(checks: checks));
    expect(result.level, LeaseReturnLevel.urgent);
    expect(result.urgentCount, 1);
  });

  test('pre inspection requires visible and handover checks', () {
    final checks =
        {
            for (final area in LeaseReturnArea.values)
              area: LeaseReturnStatus.ready,
          }
          ..[LeaseReturnArea.preInspectionAndHandover] =
              LeaseReturnStatus.notChecked;
    final result = LeaseReturnCalculator.assess(
      profile(checks: checks, context: LeaseReturnContext.beforePreInspection),
    );
    expect(
      result.findings.any((item) => item.code == 'PRE_INSPECTION_INCOMPLETE'),
      isTrue,
    );
  });
}
