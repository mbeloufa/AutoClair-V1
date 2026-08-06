import 'package:autoclair_app/features/workshop_visit/workshop_visit_preparation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured workshop area', () {
    final checks = {
      for (final area in WorkshopPreparationArea.values)
        area: WorkshopPreparationStatus.ready,
    };
    checks.remove(WorkshopPreparationArea.documents);
    final profile = WorkshopVisitPreparationProfile(
      vehicleId: 'vehicle',
      plannedDate: DateTime.now().add(const Duration(days: 3)),
      visitReason: WorkshopVisitReason.routineMaintenance,
      checks: checks,
      vehicleCanMoveSafely: true,
      warningLightOn: false,
    );

    expect(profile.validate, throwsFormatException);
  });

  test('stored map contains no garage address identity or free text', () {
    final profile = WorkshopVisitPreparationProfile(
      vehicleId: 'vehicle',
      plannedDate: DateTime.now().add(const Duration(days: 3)),
      visitReason: WorkshopVisitReason.bodywork,
      checks: {
        for (final area in WorkshopPreparationArea.values)
          area: WorkshopPreparationStatus.notChecked,
      },
      vehicleCanMoveSafely: true,
      warningLightOn: false,
    );
    final storedKeys = <String>{};

    void collectKeys(Object? value) {
      if (value is Map<Object?, Object?>) {
        for (final entry in value.entries) {
          storedKeys.add(entry.key.toString().toLowerCase());
          collectKeys(entry.value);
        }
      } else if (value is Iterable<Object?>) {
        for (final item in value) {
          collectKeys(item);
        }
      }
    }

    collectKeys(profile.toMap());

    for (final forbiddenKey in [
      'latitude',
      'longitude',
      'address',
      'garage_name',
      'contact_name',
      'vin',
      'photo',
      'free_text',
    ]) {
      expect(storedKeys, isNot(contains(forbiddenKey)));
    }
  });

  test('summary explicitly refuses diagnosis estimate and authorization', () {
    const assessment = WorkshopVisitPreparationAssessment(
      level: WorkshopPreparationLevel.review,
      score: 86,
      completenessPercent: 75,
      urgentCount: 0,
      findings: [],
    );
    final profile = WorkshopVisitPreparationProfile(
      vehicleId: 'vehicle',
      plannedDate: DateTime.now().add(const Duration(days: 3)),
      visitReason: WorkshopVisitReason.warningLight,
      checks: {
        for (final area in WorkshopPreparationArea.values)
          area: WorkshopPreparationStatus.notChecked,
      },
      vehicleCanMoveSafely: true,
      warningLightOn: true,
    );

    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: profile,
    );
    expect(summary, contains('ne pose pas de diagnostic'));
    expect(summary, contains('ni devis'));
    expect(summary, contains('ni autorisation de travaux'));
  });

  test('parses a recent stored preparation', () {
    final snapshot = WorkshopVisitPreparationSnapshot.fromMap({
      'id': 'id',
      'planned_date': '2026-08-20',
      'visit_reason': 'NOISE_OR_VIBRATION',
      'preparation_level': 'ACTION',
      'preparation_score': 61,
      'completeness_percent': 83,
    });

    expect(snapshot.visitReason, WorkshopVisitReason.noiseOrVibration);
    expect(snapshot.level, WorkshopPreparationLevel.action);
    expect(snapshot.score, 61);
  });
}
