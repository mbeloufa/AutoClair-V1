import 'package:autoclair_app/features/battery_care/battery_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured battery area', () {
    final checks = <BatteryCareArea, BatteryCareStatus>{
      for (final area in BatteryCareArea.values) area: BatteryCareStatus.normal,
    }..remove(BatteryCareArea.emergencyPlan);

    expect(
      () => _profile(checks: checks).validate(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'stored map contains no battery identity voltage location or free text',
    () {
      final map = _profile().toMap();
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

      collectKeys(map);
      for (final forbiddenKey in [
        'latitude',
        'longitude',
        'address',
        'battery_brand',
        'battery_model',
        'serial_number',
        'voltage_value',
        'photo_url',
        'vin',
        'free_text',
      ]) {
        expect(storedKeys, isNot(contains(forbiddenKey)));
      }
    },
  );

  test('summary states measurement diagnosis and professional limits', () {
    const assessment = BatteryCareAssessment(
      level: BatteryCareLevel.ready,
      score: 100,
      completenessPercent: 100,
      urgentCount: 0,
      findings: [],
    );

    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule',
      profile: _profile(),
    );

    expect(summary, contains('ne mesure aucune tension'));
    expect(summary, contains('ne diagnostique pas la batterie'));
    expect(summary, contains('un professionnel'));
  });

  test('parses a recent stored battery check', () {
    final snapshot = BatteryCareSnapshot.fromMap({
      'id': 'check',
      'checked_at': '2026-08-06',
      'check_context': 'AFTER_LONG_PARKING',
      'care_level': 'REVIEW',
      'care_score': 82,
      'completeness_percent': 90,
    });

    expect(snapshot.checkContext, BatteryCheckContext.afterLongParking);
    expect(snapshot.level, BatteryCareLevel.review);
    expect(snapshot.score, 82);
  });
}

BatteryCareProfile _profile({Map<BatteryCareArea, BatteryCareStatus>? checks}) {
  return BatteryCareProfile(
    vehicleId: 'vehicle',
    checkedAt: DateTime.now(),
    checkContext: BatteryCheckContext.routine,
    checks:
        checks ??
        {
          for (final area in BatteryCareArea.values)
            area: BatteryCareStatus.normal,
        },
    vehicleCanMoveSafely: true,
    difficultStart: false,
    recentDischarge: false,
    parkedMoreThan14Days: false,
  );
}
