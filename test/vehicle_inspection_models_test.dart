import 'package:autoclair_app/features/vehicle_inspection/vehicle_inspection_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured inspection area', () {
    final profile = VehicleInspectionProfile(
      vehicleId: 'vehicle-1',
      purpose: VehicleInspectionPurpose.routine,
      checks: const {},
      roadTestCompleted: false,
      photosAvailable: false,
      professionalCheckPlanned: false,
    );

    expect(profile.validate, throwsFormatException);
  });

  test('stored map contains no location, identity or free text', () {
    final profile = VehicleInspectionProfile.defaults('vehicle-1');
    final map = profile.toMap();
    final serialized = map.toString().toLowerCase();

    expect(serialized, isNot(contains('latitude')));
    expect(serialized, isNot(contains('longitude')));
    expect(serialized, isNot(contains('address')));
    expect(serialized, isNot(contains('free_text')));
    expect(serialized, isNot(contains('vin')));
  });

  test('summary explicitly refuses expertise and diagnosis', () {
    const assessment = VehicleInspectionAssessment(
      score: 88,
      level: VehicleInspectionLevel.monitor,
      completenessPercent: 70,
      immediateAction: false,
      checkedCount: 7,
      positiveCount: 6,
      findings: [],
    );

    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      purpose: VehicleInspectionPurpose.sale,
    );
    expect(summary, contains('ne remplace ni un contrôle technique'));
    expect(summary, contains('ni une expertise'));
    expect(summary, contains('ni un diagnostic professionnel'));
  });

  test('parses a recent inspection snapshot', () {
    final snapshot = VehicleInspectionSnapshot.fromMap({
      'id': 'inspection-1',
      'purpose': 'RETURN_LEASE',
      'condition_score': 72,
      'condition_level': 'ACTION',
      'completeness_percent': 90,
      'created_at': '2026-08-06T10:00:00Z',
    });

    expect(snapshot.purpose, VehicleInspectionPurpose.returnLease);
    expect(snapshot.level, VehicleInspectionLevel.action);
    expect(snapshot.score, 72);
  });
}
