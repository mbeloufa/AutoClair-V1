import 'package:autoclair_app/features/body_safety_care/body_safety_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BodySafetyCareProfile profile({
    Map<BodySafetyCareArea, BodySafetyCareStatus>? checks,
  }) => BodySafetyCareProfile(
    vehicleId: 'vehicle',
    checkedAt: DateTime.now(),
    checkContext: BodySafetyCheckContext.beforeControlOrSale,
    checks:
        checks ??
        {
          for (final area in BodySafetyCareArea.values)
            area: BodySafetyCareStatus.notChecked,
        },
    vehicleCanMoveSafely: true,
    closureConcern: false,
    restraintConcern: false,
    recentImpact: false,
  );

  test('profile requires every structured body safety area', () {
    final checks = {
      for (final area in BodySafetyCareArea.values)
        area: BodySafetyCareStatus.normal,
    }..remove(BodySafetyCareArea.seatBelts);
    expect(() => profile(checks: checks).validate(), throwsFormatException);
  });

  test('stored map contains no identity measurement location or free text', () {
    final stored = profile().toMap();
    final storedKeys = <String>{};

    void collectKeys(Object? value) {
      if (value is Map) {
        for (final entry in value.entries) {
          storedKeys.add(entry.key.toString().toLowerCase());
          collectKeys(entry.value);
        }
      } else if (value is Iterable) {
        for (final item in value) {
          collectKeys(item);
        }
      }
    }

    collectKeys(stored);
    for (final forbiddenKey in [
      'plate_number',
      'occupant_name',
      'part_number',
      'measurement',
      'latitude',
      'longitude',
      'address',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(storedKeys, isNot(contains(forbiddenKey)));
    }
  });

  test('summary states expertise compliance and professional limits', () {
    final assessment = BodySafetyCareAssessment(
      level: BodySafetyCareLevel.review,
      score: 90,
      completenessPercent: 90,
      urgentCount: 0,
      findings: const [],
    );
    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: profile(),
    );
    expect(summary, contains('observations visuelles déclarées'));
    expect(summary, contains('expertise structurelle'));
    expect(summary, contains('certification de conformité'));
    expect(summary, contains('professionnel'));
  });

  test('parses a recent stored body safety check', () {
    final snapshot = BodySafetyCareSnapshot.fromMap({
      'id': 'check',
      'checked_at': '2026-08-06',
      'check_context': 'AFTER_IMPACT',
      'care_level': 'ACTION',
      'care_score': 72,
      'completeness_percent': 80,
    });
    expect(snapshot.checkContext, BodySafetyCheckContext.afterImpact);
    expect(snapshot.level, BodySafetyCareLevel.action);
    expect(snapshot.score, 72);
  });
}
