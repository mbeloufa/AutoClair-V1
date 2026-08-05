import 'package:autoclair_app/features/eco_driving/eco_driving_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a stored eco-driving profile', () {
    final profile = EcoDrivingProfile.fromMap({
      'energy_type': 'electric',
      'consumption_per_100km': '17.5',
      'energy_price': 0.29,
      'potential_gain_percent': 6,
    });

    expect(profile.energyType, EcoDrivingEnergyType.electric);
    expect(profile.consumptionPer100Km, 17.5);
    expect(profile.energyPrice, 0.29);
    expect(profile.potentialGainPercent, 6);
  });

  test('infers electric energy only for explicit electric vehicles', () {
    expect(
      EcoDrivingEnergyTypeX.inferFromFuelType('Électrique'),
      EcoDrivingEnergyType.electric,
    );
    expect(
      EcoDrivingEnergyTypeX.inferFromFuelType('Hybride rechargeable'),
      EcoDrivingEnergyType.fuel,
    );
  });

  test('session meaning requires enough duration distance and samples', () {
    final summary = EcoDrivingSessionSummary(
      startedAt: DateTime.utc(2026, 8, 5),
      endedAt: DateTime.utc(2026, 8, 5, 0, 3),
      durationSeconds: 180,
      movingSeconds: 150,
      idleSeconds: 30,
      distanceKm: 1.2,
      averageSpeedKph: 28.8,
      harshAccelerationCount: 1,
      harshBrakingCount: 0,
      acceptedSampleCount: 10,
      discardedSampleCount: 1,
      score: 90,
      baselineEnergyCost: 0.14,
      potentialSaving: 0.01,
      recommendations: const ['Conseil'],
    );

    expect(summary.isMeaningful, isTrue);
    expect(summary.idleRatio, closeTo(1 / 6, 0.001));
  });
}
