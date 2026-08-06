import 'package:autoclair_app/features/visibility_care/visibility_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VisibilityCareProfile profile({
    Map<VisibilityCareArea, VisibilityCareStatus>? checks,
  }) => VisibilityCareProfile(
    vehicleId: 'vehicle',
    checkedAt: DateTime.now(),
    checkContext: VisibilityCheckContext.beforeTrip,
    checks:
        checks ??
        {
          for (final area in VisibilityCareArea.values)
            area: VisibilityCareStatus.notChecked,
        },
    vehicleCanMoveSafely: true,
    majorVisibilityObstruction: false,
    essentialLightFailure: false,
    badWeatherExpected: false,
  );

  test('profile requires every structured visibility area', () {
    final checks = {
      for (final area in VisibilityCareArea.values)
        area: VisibilityCareStatus.normal,
    }..remove(VisibilityCareArea.mirrors);
    expect(() => profile(checks: checks).validate(), throwsFormatException);
  });

  test('stored map contains no part identity location or free text', () {
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
      'latitude',
      'longitude',
      'address',
      'bulb_reference',
      'lamp_brand',
      'part_number',
      'photo_url',
      'vin',
      'free_text',
    ]) {
      expect(storedKeys, isNot(contains(forbiddenKey)));
    }
  });

  test('summary states diagnosis compliance and professional limits', () {
    final assessment = VisibilityCareAssessment(
      level: VisibilityCareLevel.review,
      score: 90,
      completenessPercent: 90,
      urgentCount: 0,
      findings: const [],
    );
    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: profile(),
    );
    expect(summary, contains('observations déclarées'));
    expect(summary, contains('diagnostique aucun circuit électrique'));
    expect(summary, contains('ne garantit ni la conformité'));
    expect(summary, contains('professionnel'));
  });

  test('parses a recent stored visibility check', () {
    final snapshot = VisibilityCareSnapshot.fromMap({
      'id': 'check',
      'checked_at': '2026-08-06',
      'check_context': 'NIGHT_DRIVING',
      'care_level': 'ACTION',
      'care_score': 72,
      'completeness_percent': 80,
    });
    expect(snapshot.checkContext, VisibilityCheckContext.nightDriving);
    expect(snapshot.level, VisibilityCareLevel.action);
    expect(snapshot.score, 72);
  });
}
