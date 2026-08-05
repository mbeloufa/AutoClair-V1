import 'dart:math' as math;

import '../charging_prices/charging_station_offer.dart';
import 'charging_optimizer_models.dart';

abstract final class ChargingOptimizerCalculator {
  static List<ChargingOptimizationResult> calculate({
    required List<ChargingStationOffer> offers,
    required ChargingOptimizationInput input,
    DateTime? now,
  }) {
    _validate(input);
    final referenceTime = now ?? DateTime.now();

    final results = <ChargingOptimizationResult>[];
    for (final offer in offers) {
      final stationCost = _stationCost(offer);
      if (stationCost == null ||
          offer.maxPowerKw <= 0 ||
          offer.distanceKm < 0) {
        continue;
      }

      final accessDistanceKm =
          offer.distanceKm * input.accessDistanceMultiplier;
      final accessEnergyKwh =
          accessDistanceKm * input.consumptionKwhPer100Km / 100;
      final accessCost = accessEnergyKwh * input.referencePricePerKwh;
      final totalCost = stationCost + accessCost;
      final referenceCost = input.energyKwh * input.referencePricePerKwh;
      final effectivePower = math.min(
        offer.maxPowerKw,
        input.vehicleMaxPowerKw,
      );
      final durationMinutes = math.max(
        1,
        (input.energyKwh / effectivePower * 60).ceil(),
      );

      results.add(
        ChargingOptimizationResult(
          offer: offer,
          stationEnergyCost: stationCost,
          accessDistanceKm: accessDistanceKm,
          accessEnergyKwh: accessEnergyKwh,
          accessCost: accessCost,
          totalEstimatedCost: totalCost,
          referenceCost: referenceCost,
          netSaving: referenceCost - totalCost,
          effectivePricePerKwh: totalCost / input.energyKwh,
          effectivePowerKw: effectivePower,
          estimatedDurationMinutes: durationMinutes,
          dataAge: offer.updatedAt == null
              ? null
              : referenceTime.isBefore(offer.updatedAt!)
              ? Duration.zero
              : referenceTime.difference(offer.updatedAt!),
        ),
      );
    }

    results.sort((left, right) {
      final savingOrder = right.netSaving.compareTo(left.netSaving);
      if (savingOrder != 0) return savingOrder;
      final costOrder = left.totalEstimatedCost.compareTo(
        right.totalEstimatedCost,
      );
      if (costOrder != 0) return costOrder;
      final durationOrder = left.estimatedDurationMinutes.compareTo(
        right.estimatedDurationMinutes,
      );
      if (durationOrder != 0) return durationOrder;
      return left.offer.distanceKm.compareTo(right.offer.distanceKm);
    });

    return List.unmodifiable(results);
  }

  static double? _stationCost(ChargingStationOffer offer) {
    if (offer.isFree || offer.pricingKind == 'free') return 0;
    if (!offer.pricingComparable || offer.estimatedCost == null) return null;
    if (offer.estimatedCost! < 0) return null;
    return offer.estimatedCost;
  }

  static void _validate(ChargingOptimizationInput input) {
    if (input.energyKwh <= 0 || input.energyKwh > 300) {
      throw const FormatException(
        'La quantité de recharge doit être comprise entre 1 et 300 kWh.',
      );
    }
    if (input.consumptionKwhPer100Km <= 0 ||
        input.consumptionKwhPer100Km > 100) {
      throw const FormatException('La consommation électrique est invalide.');
    }
    if (input.referencePricePerKwh < 0 || input.referencePricePerKwh > 5) {
      throw const FormatException('Le tarif de référence est invalide.');
    }
    if (input.vehicleMaxPowerKw <= 0 || input.vehicleMaxPowerKw > 500) {
      throw const FormatException(
        'La puissance maximale du véhicule est invalide.',
      );
    }
    if (input.accessDistanceMultiplier < 1 ||
        input.accessDistanceMultiplier > 4) {
      throw const FormatException('Le calcul de distance est invalide.');
    }
  }
}
