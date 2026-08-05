import 'package:autoclair_app/features/fuel_optimizer/fuel_optimization_models.dart';
import 'package:autoclair_app/features/fuel_optimizer/fuel_saving_calculator.dart';
import 'package:autoclair_app/features/fuel_prices/fuel_station_offer.dart';
import 'package:flutter_test/flutter_test.dart';

FuelStationOffer _offer({
  required String id,
  required double distance,
  required double price,
}) {
  return FuelStationOffer(
    stationId: id,
    address: '1 rue du Test',
    postalCode: '21000',
    city: 'Dijon',
    latitude: 47.32,
    longitude: 5.04,
    distanceKm: distance,
    fuelType: 'E10',
    availability: 'available',
    automate24h: true,
    services: const [],
    price: price,
    priceUpdatedAt: DateTime(2026, 8, 5, 12),
  );
}

void main() {
  test('calculates net saving after detour cost', () {
    final results = FuelSavingCalculator.calculate(
      offers: [
        _offer(id: 'near', distance: 1, price: 1.90),
        _offer(id: 'cheap', distance: 6, price: 1.75),
      ],
      input: const FuelOptimizationInput(
        volumeLiters: 40,
        consumptionLitersPer100Km: 6,
        detourMultiplier: 2,
      ),
      now: DateTime(2026, 8, 5, 13),
    );

    final cheap = results.firstWhere(
      (result) => result.offer.stationId == 'cheap',
    );
    expect(cheap.grossSaving, closeTo(6, 0.001));
    expect(cheap.detourDistanceKm, closeTo(10, 0.001));
    expect(cheap.detourCost, closeTo(1.14, 0.001));
    expect(cheap.netSaving, closeTo(4.86, 0.001));
  });

  test('rejects invalid consumption or volume', () {
    expect(
      () => FuelSavingCalculator.calculate(
        offers: [_offer(id: 'near', distance: 1, price: 1.90)],
        input: const FuelOptimizationInput(
          volumeLiters: 0,
          consumptionLitersPer100Km: 6,
          detourMultiplier: 2,
        ),
      ),
      throwsFormatException,
    );
  });

  test('excludes unavailable stations', () {
    final unavailable = FuelStationOffer(
      stationId: 'outage',
      address: '',
      postalCode: '',
      city: '',
      latitude: 47,
      longitude: 5,
      distanceKm: 2,
      fuelType: 'E10',
      availability: 'temporary_outage',
      automate24h: false,
      services: const [],
    );
    final results = FuelSavingCalculator.calculate(
      offers: [
        unavailable,
        _offer(id: 'near', distance: 1, price: 1.90),
      ],
      input: const FuelOptimizationInput(
        volumeLiters: 40,
        consumptionLitersPer100Km: 6,
        detourMultiplier: 2,
      ),
    );
    expect(results, hasLength(1));
    expect(results.single.offer.stationId, 'near');
  });
}
