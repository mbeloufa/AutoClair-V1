import 'package:autoclair_app/features/fluid_care/fluid_care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured fluid area', () {
    final checks = <FluidCareArea, FluidCareStatus>{
      for (final area in FluidCareArea.values) area: FluidCareStatus.normal,
    }..remove(FluidCareArea.professionalCheckPlan);

    expect(
      () => _profile(checks: checks).validate(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'stored map contains no product identity quantity location or free text',
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
        'fluid_brand',
        'product_reference',
        'quantity_value',
        'viscosity_grade',
        'photo_url',
        'vin',
        'free_text',
      ]) {
        expect(storedKeys, isNot(contains(forbiddenKey)));
      }
    },
  );

  test(
    'summary states measurement diagnosis mixing and professional limits',
    () {
      const assessment = FluidCareAssessment(
        level: FluidCareLevel.ready,
        score: 100,
        completenessPercent: 100,
        urgentCount: 0,
        findings: [],
      );

      final summary = assessment.buildShareSummary(
        vehicleLabel: 'Véhicule',
        profile: _profile(),
      );

      expect(summary, contains('ne mesure aucun niveau'));
      expect(summary, contains('ne diagnostique aucune fuite'));
      expect(summary, contains('Ne mélangez pas'));
      expect(summary, contains('un professionnel'));
    },
  );

  test('parses a recent stored fluid check', () {
    final snapshot = FluidCareSnapshot.fromMap({
      'id': 'check',
      'checked_at': '2026-08-06',
      'check_context': 'AFTER_WARNING',
      'care_level': 'REVIEW',
      'care_score': 82,
      'completeness_percent': 90,
    });

    expect(snapshot.checkContext, FluidCheckContext.afterWarning);
    expect(snapshot.level, FluidCareLevel.review);
    expect(snapshot.score, 82);
  });
}

FluidCareProfile _profile({Map<FluidCareArea, FluidCareStatus>? checks}) {
  return FluidCareProfile(
    vehicleId: 'vehicle',
    checkedAt: DateTime.now(),
    checkContext: FluidCheckContext.routine,
    checks:
        checks ??
        {for (final area in FluidCareArea.values) area: FluidCareStatus.normal},
    vehicleCanMoveSafely: true,
    visibleLeakObserved: false,
    warningMessageOn: false,
    electrifiedVehicle: false,
  );
}
