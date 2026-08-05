import '../fuel_prices/fuel_station_offer.dart';
import 'fuel_optimization_models.dart';

abstract final class FuelSavingCalculator {
  static List<FuelOptimizationResult> calculate({
    required List<FuelStationOffer> offers,
    required FuelOptimizationInput input,
    DateTime? now,
  }) {
    if (input.volumeLiters <= 0 ||
        input.consumptionLitersPer100Km <= 0 ||
        input.detourMultiplier < 1) {
      throw const FormatException('Paramètres de plein invalides.');
    }

    final available = offers
        .where((offer) => offer.isAvailable && offer.price! > 0)
        .toList(growable: false);
    if (available.isEmpty) return const [];

    final byDistance = [...available]
      ..sort((left, right) => left.distanceKm.compareTo(right.distanceKm));
    final referencePrice = byDistance.first.price!;
    final referenceDistance = byDistance.first.distanceKm;
    final reference = now ?? DateTime.now();

    final results = available
        .map((offer) {
          final stationPrice = offer.price!;
          final additionalOneWayKm = (offer.distanceKm - referenceDistance)
              .clamp(0, double.infinity)
              .toDouble();
          final detourDistanceKm = additionalOneWayKm * input.detourMultiplier;
          final detourLiters =
              detourDistanceKm * input.consumptionLitersPer100Km / 100;
          final detourCost = detourLiters * referencePrice;
          final grossSaving =
              (referencePrice - stationPrice) * input.volumeLiters;
          final netSaving = grossSaving - detourCost;
          final updatedAt = offer.priceUpdatedAt;

          return FuelOptimizationResult(
            offer: offer,
            referencePrice: referencePrice,
            fillCost: stationPrice * input.volumeLiters,
            grossSaving: grossSaving,
            detourDistanceKm: detourDistanceKm,
            detourCost: detourCost,
            netSaving: netSaving,
            priceAge: updatedAt == null
                ? null
                : reference.difference(updatedAt),
          );
        })
        .toList(growable: false);

    results.sort((left, right) {
      final savingOrder = right.netSaving.compareTo(left.netSaving);
      if (savingOrder != 0) return savingOrder;
      final freshnessOrder = (left.priceAge?.inMinutes ?? 999999).compareTo(
        right.priceAge?.inMinutes ?? 999999,
      );
      if (freshnessOrder != 0) return freshnessOrder;
      return left.offer.distanceKm.compareTo(right.offer.distanceKm);
    });
    return results;
  }
}
