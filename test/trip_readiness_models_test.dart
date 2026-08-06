import 'package:autoclair_app/features/trip_readiness/trip_readiness_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile requires every structured readiness area', () {
    final profile = TripReadinessProfile(
      vehicleId: 'vehicle-1',
      departureDate: DateTime(2026, 8, 20),
      purpose: TripPurpose.weekend,
      checks: const {},
      longDistance: false,
      towing: false,
      coldConditions: false,
      youngPassengers: false,
      breakdownCoverageKnown: false,
    );

    expect(
      () => profile.validate(now: DateTime(2026, 8, 6)),
      throwsFormatException,
    );
  });

  test('stored map contains no destination location or itinerary', () {
    final map = _profile().toMap();
    final serialized = map.toString().toLowerCase();

    expect(serialized, isNot(contains('destination')));
    expect(serialized, isNot(contains('latitude')));
    expect(serialized, isNot(contains('longitude')));
    expect(serialized, isNot(contains('itinerary')));
    expect(serialized, contains('departure_date'));
  });

  test('summary explains privacy and operational limits', () {
    final assessment = TripReadinessAssessment(
      level: TripReadinessLevel.review,
      score: 80,
      completenessPercent: 70,
      blockingCount: 0,
      findings: const [],
    );
    final summary = assessment.buildShareSummary(
      vehicleLabel: 'Véhicule test',
      profile: _profile(),
    );

    expect(summary, contains('n’enregistre ni destination ni itinéraire'));
    expect(summary, contains('météo'));
    expect(summary, isNot(contains('adresse')));
  });

  test('parses a recent stored preparation', () {
    final snapshot = TripReadinessSnapshot.fromMap({
      'id': 'check-1',
      'departure_date': '2026-08-20',
      'purpose': 'HOLIDAY',
      'readiness_score': 85,
      'readiness_level': 'REVIEW',
      'completeness_percent': 90,
    });

    expect(snapshot.purpose, TripPurpose.holiday);
    expect(snapshot.level, TripReadinessLevel.review);
    expect(snapshot.score, 85);
  });
}

TripReadinessProfile _profile() => TripReadinessProfile(
  vehicleId: 'vehicle-1',
  departureDate: DateTime(2026, 8, 20),
  purpose: TripPurpose.holiday,
  checks: {
    for (final area in TripReadinessArea.values) area: TripCheckStatus.ready,
  },
  longDistance: true,
  towing: false,
  coldConditions: false,
  youngPassengers: true,
  breakdownCoverageKnown: true,
);
