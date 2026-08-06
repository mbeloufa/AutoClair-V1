import 'package:autoclair_app/features/tire_care/tire_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured tire area', () {
    final checks = <TireCareArea, TireCareStatus>{
      for (final area in TireCareArea.values) area: TireCareStatus.good,
    }..remove(TireCareArea.sidewalls);
    final profile = TireCareProfile(
      vehicleId: 'vehicle',
      checkedAt: DateTime.now(),
      checkContext: TireCheckContext.routine,
      checks: checks,
      vehicleCanMoveSafely: true,
      vibrationOrPulling: false,
      recentImpact: false,
    );
    expect(() => profile.validate(), throwsFormatException);
  });

  test('stored map contains no tire identity location or free text', () {
    final profile = _profile();
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

    collectKeys(profile.toMap());
    for (final forbiddenKey in [
      'latitude',
      'longitude',
      'address',
      'tire_brand',
      'dot_code',
      'pressure_value',
      'photo',
      'vin',
      'free_text',
    ]) {
      expect(storedKeys, isNot(contains(forbiddenKey)));
    }
  });

  test('summary states manufacturer and professional limits', () {
    final assessment = TireCareAssessment(
      level: TireCareLevel.review,
      score: 90,
      completenessPercent: 90,
      urgentCount: 0,
      findings: const [],
    );
    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: _profile(),
    );
    expect(summary, contains('aucune pression constructeur'));
    expect(summary, contains('ne confirme pas la conformité'));
    expect(summary, contains('professionnel'));
  });

  test('parses a recent stored tire check', () {
    final snapshot = TireCareSnapshot.fromMap({
      'id': 'id',
      'checked_at': '2026-08-06',
      'check_context': 'AFTER_IMPACT',
      'care_level': 'ACTION',
      'care_score': 63,
      'completeness_percent': 100,
    });
    expect(snapshot.checkContext, TireCheckContext.afterImpact);
    expect(snapshot.level, TireCareLevel.action);
    expect(snapshot.score, 63);
  });
}

TireCareProfile _profile() => TireCareProfile(
  vehicleId: 'vehicle',
  checkedAt: DateTime.now(),
  checkContext: TireCheckContext.routine,
  checks: {for (final area in TireCareArea.values) area: TireCareStatus.good},
  vehicleCanMoveSafely: true,
  vibrationOrPulling: false,
  recentImpact: false,
);
