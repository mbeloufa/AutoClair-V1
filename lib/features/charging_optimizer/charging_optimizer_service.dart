import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/finance/financial_impact_service.dart';
import '../../core/finance/saving_status.dart';
import '../charging_prices/charging_service.dart';
import '../charging_prices/charging_station_offer.dart';
import 'charging_optimizer_models.dart';

class ChargingOptimizerException implements Exception {
  const ChargingOptimizerException(this.message);

  final String message;
}

class ChargingOptimizerService {
  final FinancialImpactService _financial = FinancialImpactService();
  final ChargingService _charging = ChargingService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<VehicleChargingProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_charging_profiles')
          .select(
            'consumption_kwh_per_100km,usual_charge_kwh,'
            'reference_price_per_kwh,max_charging_power_kw,'
            'battery_capacity_kwh,connector',
          )
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      return row == null ? null : VehicleChargingProfile.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return null;
      throw ChargingOptimizerException(_message(error));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile({
    required String vehicleId,
    required VehicleChargingProfile profile,
  }) async {
    _validateProfile(profile);
    try {
      await _client.from('vehicle_charging_profiles').upsert({
        'vehicle_id': vehicleId,
        'consumption_kwh_per_100km': profile.consumptionKwhPer100Km,
        'usual_charge_kwh': profile.usualChargeKwh,
        'reference_price_per_kwh': profile.referencePricePerKwh,
        'max_charging_power_kw': profile.maxChargingPowerKw,
        'battery_capacity_kwh': profile.batteryCapacityKwh,
        'connector': profile.connector,
      }, onConflict: 'vehicle_id');
    } on PostgrestException catch (error) {
      throw ChargingOptimizerException(_message(error));
    }
  }

  Future<ChargingSearchResult> searchStations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String connector,
    required double minimumPowerKw,
    required double energyKwh,
  }) async {
    try {
      return await _charging.searchStations(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        connector: connector,
        minimumPowerKw: minimumPowerKw,
        energyKwh: energyKwh,
        sortBy: 'price',
        resultLimit: 50,
      );
    } on ChargingServiceException catch (error) {
      throw ChargingOptimizerException(error.message);
    }
  }

  Future<void> confirmSession({
    required String vehicleId,
    required ChargingOptimizationResult result,
    required double energyKwh,
  }) async {
    if (energyKwh <= 0 || result.stationEnergyCost < 0) {
      throw const ChargingOptimizerException(
        'Les informations de recharge sont invalides.',
      );
    }

    final reference =
        'charging-${result.offer.stationId}-'
        '${DateTime.now().millisecondsSinceEpoch}';

    try {
      await _financial.recordCost(
        vehicleId: vehicleId,
        category: 'CHARGING',
        subcategory: result.offer.displayName,
        amount: result.stationEnergyCost,
        eventDate: DateTime.now(),
        sourceType: 'CHARGING_OPTIMIZER',
        sourceReference: reference,
        note:
            '${energyKwh.toStringAsFixed(1)} kWh · '
            'coût complet estimé '
            '${result.totalEstimatedCost.toStringAsFixed(2)} €',
      );

      if (result.isWorthwhile) {
        await _financial.recordOpportunity(
          vehicleId: vehicleId,
          featureCode: 'CHARGING_OPTIMIZER',
          baselineAmount: result.referenceCost,
          proposedAmount: result.totalEstimatedCost,
          calculationDetails: {
            'station_id': result.offer.stationId,
            'network_name': result.offer.networkName,
            'energy_kwh': energyKwh,
            'station_cost': result.stationEnergyCost,
            'access_distance_km': result.accessDistanceKm,
            'access_energy_kwh': result.accessEnergyKwh,
            'access_cost': result.accessCost,
            'effective_price_per_kwh': result.effectivePricePerKwh,
            'estimated_duration_minutes': result.estimatedDurationMinutes,
            'confidence': result.dataAge != null && result.dataAge!.inHours < 24
                ? 'HIGH'
                : 'MEDIUM',
          },
          status: SavingStatus.confirmed,
          sourceReference: reference,
        );
      }
    } on FinancialImpactException catch (error) {
      throw ChargingOptimizerException(error.message);
    }
  }

  static void _validateProfile(VehicleChargingProfile profile) {
    if (profile.consumptionKwhPer100Km <= 0 ||
        profile.consumptionKwhPer100Km > 100 ||
        profile.usualChargeKwh <= 0 ||
        profile.usualChargeKwh > 300 ||
        profile.referencePricePerKwh < 0 ||
        profile.referencePricePerKwh > 5 ||
        profile.maxChargingPowerKw <= 0 ||
        profile.maxChargingPowerKw > 500 ||
        profile.batteryCapacityKwh != null &&
            (profile.batteryCapacityKwh! <= 0 ||
                profile.batteryCapacityKwh! > 300)) {
      throw const ChargingOptimizerException(
        'Le profil de recharge contient une valeur invalide.',
      );
    }
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    if (raw.contains('AUTH_REQUIRED') || raw.toLowerCase().contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('VEHICLE_FORBIDDEN')) {
      return "Ce véhicule n'est plus accessible.";
    }
    if (raw.toLowerCase().contains('relation')) {
      return 'Le profil de recharge doit être installé sur Supabase.';
    }
    return "Le profil de recharge n'a pas pu être enregistré.";
  }
}
