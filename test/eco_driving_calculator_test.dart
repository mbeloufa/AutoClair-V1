import 'package:autoclair_app/features/eco_driving/eco_driving_calculator.dart';
import 'package:autoclair_app/features/eco_driving/eco_driving_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = EcoDrivingProfile(
    energyType: EcoDrivingEnergyType.fuel,
    consumptionPer100Km: 6.5,
    energyPrice: 1.85,
    potentialGainPercent: 5,
  );

  test('smooth trip keeps a high score without harsh events', () {
    final start = DateTime.utc(2026, 8, 5, 18);
    final analyzer = EcoDrivingTripAnalyzer(startedAt: start);

    analyzer.addSample(
      EcoDrivingSample(
        timestamp: start,
        latitude: 48.0,
        longitude: 2.0,
        speedMps: 10,
        accuracyMeters: 5,
      ),
    );
    analyzer.addSample(
      EcoDrivingSample(
        timestamp: start.add(const Duration(seconds: 10)),
        latitude: 48.0,
        longitude: 2.0014,
        speedMps: 10,
        accuracyMeters: 5,
      ),
    );
    analyzer.addSample(
      EcoDrivingSample(
        timestamp: start.add(const Duration(seconds: 20)),
        latitude: 48.0,
        longitude: 2.0028,
        speedMps: 10,
        accuracyMeters: 5,
      ),
    );

    final summary = analyzer.finish(
      profile: profile,
      endedAt: start.add(const Duration(minutes: 3)),
    );

    expect(summary.distanceKm, greaterThan(0.15));
    expect(summary.harshAccelerationCount, 0);
    expect(summary.harshBrakingCount, 0);
    expect(summary.score, greaterThanOrEqualTo(90));
    expect(summary.potentialSaving, 0);
  });

  test('harsh acceleration and braking lower the score', () {
    final start = DateTime.utc(2026, 8, 5, 18);
    final analyzer = EcoDrivingTripAnalyzer(startedAt: start);

    analyzer.addSample(
      EcoDrivingSample(
        timestamp: start,
        latitude: 48.0,
        longitude: 2.0,
        speedMps: 0,
        accuracyMeters: 5,
      ),
    );
    analyzer.addSample(
      EcoDrivingSample(
        timestamp: start.add(const Duration(seconds: 2)),
        latitude: 48.0,
        longitude: 2.0002,
        speedMps: 15,
        accuracyMeters: 5,
      ),
    );
    analyzer.addSample(
      EcoDrivingSample(
        timestamp: start.add(const Duration(seconds: 4)),
        latitude: 48.0,
        longitude: 2.0004,
        speedMps: 0,
        accuracyMeters: 5,
      ),
    );
    for (var index = 1; index <= 4; index++) {
      analyzer.addSample(
        EcoDrivingSample(
          timestamp: start.add(Duration(seconds: 4 + index * 20)),
          latitude: 48.0,
          longitude: 2.0004 + index * 0.002,
          speedMps: 10,
          accuracyMeters: 5,
        ),
      );
    }

    final summary = analyzer.finish(
      profile: profile,
      endedAt: start.add(const Duration(minutes: 4)),
    );

    expect(summary.harshAccelerationCount, greaterThan(0));
    expect(summary.harshBrakingCount, greaterThan(0));
    expect(summary.score, lessThan(90));
    expect(summary.potentialSaving, greaterThan(0));
  });

  test('inaccurate samples are discarded without storing a route', () {
    final start = DateTime.utc(2026, 8, 5, 18);
    final analyzer = EcoDrivingTripAnalyzer(startedAt: start);

    analyzer.addSample(
      EcoDrivingSample(
        timestamp: start,
        latitude: 48,
        longitude: 2,
        speedMps: 5,
        accuracyMeters: 100,
      ),
    );
    final metrics = analyzer.addSample(
      EcoDrivingSample(
        timestamp: start.add(const Duration(seconds: 5)),
        latitude: 48,
        longitude: 2,
        speedMps: 5,
        accuracyMeters: 5,
      ),
    );

    expect(metrics.acceptedSampleCount, 1);
    expect(metrics.discardedSampleCount, 1);
  });

  test('invalid profile values are rejected', () {
    final analyzer = EcoDrivingTripAnalyzer();
    expect(
      () => analyzer.finish(
        profile: const EcoDrivingProfile(
          energyType: EcoDrivingEnergyType.fuel,
          consumptionPer100Km: 0,
          energyPrice: 1.85,
          potentialGainPercent: 5,
        ),
      ),
      throwsFormatException,
    );
  });
}
