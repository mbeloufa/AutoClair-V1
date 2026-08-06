import 'package:autoclair_app/features/technical_control_readiness/technical_control_readiness_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured control area', () {
    final checks = {
      for (final area in TechnicalControlArea.values)
        area: TechnicalControlCheckStatus.satisfactory,
    };
    checks.remove(TechnicalControlArea.visibility);
    final profile = TechnicalControlReadinessProfile(
      vehicleId: 'vehicle',
      plannedDate: DateTime.now().add(const Duration(days: 3)),
      visitContext: TechnicalControlVisitContext.periodic,
      checks: checks,
      vehicleCanMoveSafely: true,
      warningLightOn: false,
    );

    expect(profile.validate, throwsFormatException);
  });

  test('stored map contains no location vin photo or free text', () {
    final profile = TechnicalControlReadinessProfile(
      vehicleId: 'vehicle',
      plannedDate: DateTime.now().add(const Duration(days: 3)),
      visitContext: TechnicalControlVisitContext.sale,
      checks: {
        for (final area in TechnicalControlArea.values)
          area: TechnicalControlCheckStatus.notChecked,
      },
      vehicleCanMoveSafely: true,
      warningLightOn: false,
    );
    final raw = profile.toMap().toString().toLowerCase();

    for (final forbidden in [
      'latitude',
      'longitude',
      'address',
      'vin',
      'photo',
      'free_text',
    ]) {
      expect(raw, isNot(contains(forbidden)));
    }
  });

  test('summary explicitly refuses a guaranteed result', () {
    const assessment = TechnicalControlReadinessAssessment(
      level: TechnicalControlReadinessLevel.review,
      score: 82,
      completenessPercent: 75,
      blockingCount: 0,
      findings: [],
    );
    final profile = TechnicalControlReadinessProfile(
      vehicleId: 'vehicle',
      plannedDate: DateTime.now().add(const Duration(days: 3)),
      visitContext: TechnicalControlVisitContext.periodic,
      checks: {
        for (final area in TechnicalControlArea.values)
          area: TechnicalControlCheckStatus.notChecked,
      },
      vehicleCanMoveSafely: true,
      warningLightOn: false,
    );

    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: profile,
    );
    expect(summary, contains('ne garantit pas le résultat'));
    expect(summary, contains('centre agréé'));
  });

  test('parses a recent stored preparation', () {
    final snapshot = TechnicalControlReadinessSnapshot.fromMap({
      'id': 'id',
      'planned_date': '2026-08-20',
      'visit_context': 'COUNTER_VISIT',
      'readiness_level': 'ACTION',
      'readiness_score': 61,
      'completeness_percent': 83,
    });

    expect(snapshot.visitContext, TechnicalControlVisitContext.counterVisit);
    expect(snapshot.level, TechnicalControlReadinessLevel.action);
    expect(snapshot.score, 61);
  });
}
