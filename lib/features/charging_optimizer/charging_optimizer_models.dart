import '../charging_prices/charging_station_offer.dart';

class ChargingOptimizationInput {
  const ChargingOptimizationInput({
    required this.energyKwh,
    required this.consumptionKwhPer100Km,
    required this.referencePricePerKwh,
    required this.vehicleMaxPowerKw,
    this.accessDistanceMultiplier = 2,
  });

  final double energyKwh;
  final double consumptionKwhPer100Km;
  final double referencePricePerKwh;
  final double vehicleMaxPowerKw;
  final double accessDistanceMultiplier;
}

class ChargingOptimizationResult {
  const ChargingOptimizationResult({
    required this.offer,
    required this.stationEnergyCost,
    required this.accessDistanceKm,
    required this.accessEnergyKwh,
    required this.accessCost,
    required this.totalEstimatedCost,
    required this.referenceCost,
    required this.netSaving,
    required this.effectivePricePerKwh,
    required this.effectivePowerKw,
    required this.estimatedDurationMinutes,
    required this.dataAge,
  });

  final ChargingStationOffer offer;
  final double stationEnergyCost;
  final double accessDistanceKm;
  final double accessEnergyKwh;
  final double accessCost;
  final double totalEstimatedCost;
  final double referenceCost;
  final double netSaving;
  final double effectivePricePerKwh;
  final double effectivePowerKw;
  final int estimatedDurationMinutes;
  final Duration? dataAge;

  bool get isWorthwhile => netSaving > 0.05;

  String get freshnessLabel {
    final age = dataAge;
    if (age == null) return 'Fraîcheur inconnue';
    if (age.inMinutes < 60) return 'Mis à jour il y a ${age.inMinutes} min';
    if (age.inHours < 24) return 'Mis à jour il y a ${age.inHours} h';
    return 'Donnée ancienne : ${age.inDays} j';
  }
}

class VehicleChargingProfile {
  const VehicleChargingProfile({
    required this.consumptionKwhPer100Km,
    required this.usualChargeKwh,
    required this.referencePricePerKwh,
    required this.maxChargingPowerKw,
    required this.connector,
    this.batteryCapacityKwh,
  });

  final double consumptionKwhPer100Km;
  final double usualChargeKwh;
  final double referencePricePerKwh;
  final double maxChargingPowerKw;
  final String connector;
  final double? batteryCapacityKwh;

  factory VehicleChargingProfile.fromMap(Map<String, dynamic> map) {
    return VehicleChargingProfile(
      consumptionKwhPer100Km: _decimal(map['consumption_kwh_per_100km']),
      usualChargeKwh: _decimal(map['usual_charge_kwh']),
      referencePricePerKwh: _decimal(map['reference_price_per_kwh']),
      maxChargingPowerKw: _decimal(map['max_charging_power_kw']),
      connector: map['connector']?.toString().trim().isNotEmpty == true
          ? map['connector'].toString().trim()
          : 'any',
      batteryCapacityKwh: _nullableDecimal(map['battery_capacity_kwh']),
    );
  }
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

double? _nullableDecimal(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}
