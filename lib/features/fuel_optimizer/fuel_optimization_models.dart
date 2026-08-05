import '../fuel_prices/fuel_station_offer.dart';

class FuelOptimizationInput {
  const FuelOptimizationInput({
    required this.volumeLiters,
    required this.consumptionLitersPer100Km,
    required this.detourMultiplier,
  });

  final double volumeLiters;
  final double consumptionLitersPer100Km;
  final double detourMultiplier;
}

class FuelOptimizationResult {
  const FuelOptimizationResult({
    required this.offer,
    required this.referencePrice,
    required this.fillCost,
    required this.grossSaving,
    required this.detourDistanceKm,
    required this.detourCost,
    required this.netSaving,
    required this.priceAge,
  });

  final FuelStationOffer offer;
  final double referencePrice;
  final double fillCost;
  final double grossSaving;
  final double detourDistanceKm;
  final double detourCost;
  final double netSaving;
  final Duration? priceAge;

  bool get isWorthwhile => netSaving > 0.05;

  String get freshnessLabel {
    final age = priceAge;
    if (age == null) return 'Fraîcheur inconnue';
    if (age.inMinutes < 60) return 'Mis à jour il y a ${age.inMinutes} min';
    if (age.inHours < 24) return 'Mis à jour il y a ${age.inHours} h';
    return 'Prix ancien : ${age.inDays} j';
  }
}

class FuelFinancialProfile {
  const FuelFinancialProfile({
    required this.consumptionLitersPer100Km,
    required this.usualFillLiters,
  });

  final double consumptionLitersPer100Km;
  final double usualFillLiters;
}
