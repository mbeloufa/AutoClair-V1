import 'package:autoclair_app/features/vehicle_storage/vehicle_storage_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured storage area', () {
    final profile = VehicleStorageProfile(
      vehicleId: 'vehicle-1',
      plannedStartDate: DateTime(2026, 8, 20),
      plannedWeeks: 4,
      scenario: VehicleStorageScenario.shortPause,
      checks: const {},
      electricOrHybrid: false,
      outdoorStorage: false,
      humidEnvironment: false,
    );

    expect(
      () => profile.validate(now: DateTime(2026, 8, 6)),
      throwsFormatException,
    );
  });

  test('stored map contains no location vin or free text', () {
    final serialized = _profile().toMap().toString().toLowerCase();

    expect(serialized, isNot(contains('latitude')));
    expect(serialized, isNot(contains('longitude')));
    expect(serialized, isNot(contains('address')));
    expect(serialized, isNot(contains('vin')));
    expect(serialized, isNot(contains('comment')));
    expect(serialized, contains('planned_weeks'));
  });

  test('summary states privacy and professional limits', () {
    const assessment = VehicleStorageAssessment(
      level: VehicleStorageLevel.review,
      score: 82,
      completenessPercent: 75,
      blockingCount: 0,
      findings: [],
    );
    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: _profile(),
    );

    expect(summary, contains('n’enregistre aucun lieu de stockage'));
    expect(summary, contains('manuel constructeur'));
    expect(summary, isNot(contains('adresse')));
  });

  test('parses a recent stored preparation', () {
    final snapshot = VehicleStorageSnapshot.fromMap({
      'id': 'storage-1',
      'planned_start_date': '2026-08-20',
      'planned_weeks': 12,
      'scenario': 'WINTER_STORAGE',
      'readiness_score': 84,
      'readiness_level': 'REVIEW',
      'completeness_percent': 90,
    });

    expect(snapshot.scenario, VehicleStorageScenario.winterStorage);
    expect(snapshot.level, VehicleStorageLevel.review);
    expect(snapshot.plannedWeeks, 12);
  });
}

VehicleStorageProfile _profile() => VehicleStorageProfile(
  vehicleId: 'vehicle-1',
  plannedStartDate: DateTime(2026, 8, 20),
  plannedWeeks: 8,
  scenario: VehicleStorageScenario.longStorage,
  checks: {
    for (final area in VehicleStorageArea.values)
      area: area == VehicleStorageArea.tractionBattery
          ? VehicleStorageStatus.notApplicable
          : VehicleStorageStatus.ready,
  },
  electricOrHybrid: false,
  outdoorStorage: true,
  humidEnvironment: false,
);
