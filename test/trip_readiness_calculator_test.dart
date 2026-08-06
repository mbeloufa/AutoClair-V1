import 'package:autoclair_app/features/trip_readiness/trip_readiness_calculator.dart';
import 'package:autoclair_app/features/trip_readiness/trip_readiness_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete ready checklist allows a prepared departure', () {
    final assessment = TripReadinessCalculator.assess(
      _profile(
        checks: {
          for (final area in TripReadinessArea.values)
            area: TripCheckStatus.ready,
        },
        breakdownCoverageKnown: true,
      ),
    );

    expect(assessment.score, 100);
    expect(assessment.completenessPercent, 100);
    expect(assessment.level, TripReadinessLevel.ready);
    expect(assessment.blockingCount, 0);
  });

  test('blocking tire check prevents a ready status', () {
    final assessment = TripReadinessCalculator.assess(
      _profile(
        checks: {
          for (final area in TripReadinessArea.values)
            area: area == TripReadinessArea.tires
                ? TripCheckStatus.blocking
                : TripCheckStatus.ready,
        },
        breakdownCoverageKnown: true,
      ),
    );

    expect(assessment.level, TripReadinessLevel.blocked);
    expect(assessment.blockingCount, greaterThanOrEqualTo(1));
    expect(assessment.findings.first.blocking, isTrue);
  });

  test('long journey without confirmed rest becomes blocking', () {
    final assessment = TripReadinessCalculator.assess(
      _profile(
        longDistance: true,
        checks: {
          for (final area in TripReadinessArea.values)
            area: area == TripReadinessArea.driverRest
                ? TripCheckStatus.attention
                : TripCheckStatus.ready,
        },
        breakdownCoverageKnown: true,
      ),
    );

    expect(assessment.level, TripReadinessLevel.blocked);
    expect(
      assessment.findings.any(
        (finding) => finding.code == 'LONG_DISTANCE_REST',
      ),
      isTrue,
    );
  });

  test('winter context explains an unconfirmed tire check', () {
    final assessment = TripReadinessCalculator.assess(
      _profile(
        coldConditions: true,
        checks: {
          for (final area in TripReadinessArea.values)
            area: area == TripReadinessArea.tires
                ? TripCheckStatus.attention
                : TripCheckStatus.ready,
        },
        breakdownCoverageKnown: true,
      ),
    );

    expect(
      assessment.findings.any((finding) => finding.code == 'COLD_TIRES'),
      isTrue,
    );
  });

  test('unchecked points reduce completeness without hiding the score', () {
    final checks = {
      for (final area in TripReadinessArea.values)
        area: TripCheckStatus.notChecked,
    };
    checks[TripReadinessArea.vehicleDocuments] = TripCheckStatus.ready;
    final assessment = TripReadinessCalculator.assess(
      _profile(checks: checks, breakdownCoverageKnown: true),
    );

    expect(assessment.completenessPercent, 10);
    expect(assessment.score, 100);
    expect(assessment.level, TripReadinessLevel.review);
  });

  test('unknown breakdown coverage remains an explicit recommendation', () {
    final assessment = TripReadinessCalculator.assess(
      _profile(
        checks: {
          for (final area in TripReadinessArea.values)
            area: TripCheckStatus.ready,
        },
      ),
    );

    expect(
      assessment.findings.any(
        (finding) => finding.code == 'BREAKDOWN_COVERAGE',
      ),
      isTrue,
    );
  });
}

TripReadinessProfile _profile({
  Map<TripReadinessArea, TripCheckStatus>? checks,
  bool longDistance = false,
  bool towing = false,
  bool coldConditions = false,
  bool youngPassengers = false,
  bool breakdownCoverageKnown = false,
}) {
  return TripReadinessProfile(
    vehicleId: '11111111-1111-1111-1111-111111111111',
    departureDate: DateTime.now().add(const Duration(days: 14)),
    purpose: TripPurpose.holiday,
    checks:
        checks ??
        {
          for (final area in TripReadinessArea.values)
            area: TripCheckStatus.notChecked,
        },
    longDistance: longDistance,
    towing: towing,
    coldConditions: coldConditions,
    youngPassengers: youngPassengers,
    breakdownCoverageKnown: breakdownCoverageKnown,
  );
}
