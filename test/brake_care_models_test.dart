import 'package:autoclair_app/features/brake_care/brake_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BrakeCareProfile profile({Map<BrakeCareArea, BrakeCareStatus>? checks}) =>
      BrakeCareProfile(
        vehicleId: 'vehicle',
        checkedAt: DateTime.now(),
        checkContext: BrakeCheckContext.beforeTrip,
        checks:
            checks ??
            {
              for (final area in BrakeCareArea.values)
                area: BrakeCareStatus.notChecked,
            },
        vehicleCanMoveSafely: true,
        brakingAnomaly: false,
        steeringInstability: false,
        recentImpact: false,
      );

  test('profile requires every structured brake area', () {
    final checks = {
      for (final area in BrakeCareArea.values) area: BrakeCareStatus.normal,
    }..remove(BrakeCareArea.steeringFeel);
    expect(() => profile(checks: checks).validate(), throwsFormatException);
  });

  test(
    'stored map contains no part identity measurement location or free text',
    () {
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
        'part_number',
        'brake_brand',
        'pad_thickness',
        'stopping_distance',
        'photo_url',
        'vin',
        'free_text',
      ]) {
        expect(storedKeys, isNot(contains(forbiddenKey)));
      }
    },
  );

  test('summary states diagnosis measurement and professional limits', () {
    final assessment = BrakeCareAssessment(
      level: BrakeCareLevel.review,
      score: 90,
      completenessPercent: 90,
      urgentCount: 0,
      findings: const [],
    );
    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: profile(),
    );
    expect(summary, contains('sensations et observations déclarées'));
    expect(summary, contains('ne diagnostique aucun système de freinage'));
    expect(summary, contains('ne mesure'));
    expect(summary, contains('professionnel'));
  });

  test('parses a recent stored brake check', () {
    final snapshot = BrakeCareSnapshot.fromMap({
      'id': 'check',
      'checked_at': '2026-08-06',
      'check_context': 'UNUSUAL_BRAKING',
      'care_level': 'ACTION',
      'care_score': 72,
      'completeness_percent': 80,
    });
    expect(snapshot.checkContext, BrakeCheckContext.unusualBraking);
    expect(snapshot.level, BrakeCareLevel.action);
    expect(snapshot.score, 72);
  });
}
