import 'package:autoclair_app/features/charging_optimizer/charging_optimizer_calculator.dart';
import 'package:autoclair_app/features/charging_optimizer/charging_optimizer_models.dart';
import 'package:autoclair_app/features/charging_prices/charging_station_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calculates full charging cost, access cost and theoretical duration',
    () {
      final results = ChargingOptimizerCalculator.calculate(
        offers: [_offer()],
        input: const ChargingOptimizationInput(
          energyKwh: 40,
          consumptionKwhPer100Km: 18,
          referencePricePerKwh: 0.45,
          vehicleMaxPowerKw: 100,
        ),
        now: DateTime.utc(2026, 8, 5, 20),
      );

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.stationEnergyCost, closeTo(12, 0.001));
      expect(result.accessDistanceKm, closeTo(10, 0.001));
      expect(result.accessEnergyKwh, closeTo(1.8, 0.001));
      expect(result.accessCost, closeTo(0.81, 0.001));
      expect(result.totalEstimatedCost, closeTo(12.81, 0.001));
      expect(result.referenceCost, closeTo(18, 0.001));
      expect(result.netSaving, closeTo(5.19, 0.001));
      expect(result.effectivePricePerKwh, closeTo(0.32025, 0.00001));
      expect(result.effectivePowerKw, 100);
      expect(result.estimatedDurationMinutes, 24);
      expect(result.isWorthwhile, isTrue);
    },
  );

  test('excludes tariffs that are not financially comparable', () {
    final results = ChargingOptimizerCalculator.calculate(
      offers: [_offer(comparable: false, estimatedCost: null)],
      input: const ChargingOptimizationInput(
        energyKwh: 20,
        consumptionKwhPer100Km: 18,
        referencePricePerKwh: 0.45,
        vehicleMaxPowerKw: 100,
      ),
    );

    expect(results, isEmpty);
  });

  test('caps theoretical duration at the vehicle charging power', () {
    final result = ChargingOptimizerCalculator.calculate(
      offers: [_offer(maxPowerKw: 350)],
      input: const ChargingOptimizationInput(
        energyKwh: 60,
        consumptionKwhPer100Km: 18,
        referencePricePerKwh: 0.45,
        vehicleMaxPowerKw: 120,
      ),
    ).single;

    expect(result.effectivePowerKw, 120);
    expect(result.estimatedDurationMinutes, 30);
  });

  test('rejects invalid charging inputs', () {
    expect(
      () => ChargingOptimizerCalculator.calculate(
        offers: [_offer()],
        input: const ChargingOptimizationInput(
          energyKwh: 0,
          consumptionKwhPer100Km: 18,
          referencePricePerKwh: 0.45,
          vehicleMaxPowerKw: 100,
        ),
      ),
      throwsFormatException,
    );
  });
}

ChargingStationOffer _offer({
  bool comparable = true,
  double? estimatedCost = 12,
  double maxPowerKw = 150,
}) {
  return ChargingStationOffer(
    stationId: 'FRTESTE1',
    stationName: 'Borne test',
    networkName: 'Réseau test',
    operatorName: 'Opérateur test',
    address: '1 rue Exemple 21000 Dijon',
    latitude: 47.32,
    longitude: 5.04,
    distanceKm: 5,
    maxPowerKw: maxPowerKw,
    connectors: const ['Combo CCS'],
    pointCount: 4,
    isFree: false,
    pricingKind: comparable ? 'simple' : 'complex',
    pricingComparable: comparable,
    unitPricePerKwh: comparable ? 0.30 : null,
    sessionFee: 0,
    estimatedCost: estimatedCost,
    paymentAtTerminal: true,
    paymentCard: true,
    paymentOther: false,
    reservation: false,
    updatedAt: DateTime.utc(2026, 8, 5, 19),
  );
}
