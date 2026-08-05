import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/finance/financial_impact_service.dart';
import '../../core/finance/saving_status.dart';
import 'fuel_optimization_models.dart';

class FuelOptimizerException implements Exception {
  const FuelOptimizerException(this.message);

  final String message;
}

class FuelOptimizerService {
  final FinancialImpactService _financial = FinancialImpactService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<FuelFinancialProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_financial_profiles')
          .select('consumption_l_per_100km,usual_fill_liters')
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return FuelFinancialProfile(
        consumptionLitersPer100Km: _decimal(row['consumption_l_per_100km']),
        usualFillLiters: _decimal(row['usual_fill_liters']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile({
    required String vehicleId,
    required double consumption,
    required double fillLiters,
  }) async {
    if (consumption <= 0 || fillLiters <= 0) {
      throw const FuelOptimizerException(
        'La consommation et le volume doivent être positifs.',
      );
    }
    try {
      await _client.from('vehicle_financial_profiles').upsert({
        'vehicle_id': vehicleId,
        'consumption_l_per_100km': consumption,
        'usual_fill_liters': fillLiters,
      }, onConflict: 'vehicle_id');
    } on PostgrestException catch (error) {
      throw FuelOptimizerException(_message(error));
    }
  }

  Future<void> confirmFill({
    required String vehicleId,
    required FuelOptimizationResult result,
    required double volumeLiters,
  }) async {
    if (!result.isWorthwhile) {
      throw const FuelOptimizerException(
        "Cette station ne génère pas d'économie nette positive.",
      );
    }

    final referenceCost = result.referencePrice * volumeLiters;
    final actualCost = result.fillCost + result.detourCost;
    final reference =
        'fuel-${result.offer.stationId}-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await _financial.recordCost(
        vehicleId: vehicleId,
        category: 'FUEL',
        subcategory: '${result.offer.fuelType} · ${result.offer.city}',
        amount: result.fillCost,
        eventDate: DateTime.now(),
        sourceType: 'FUEL_OPTIMIZER',
        sourceReference: reference,
        note:
            '${volumeLiters.toStringAsFixed(1)} L à '
            '${result.offer.price!.toStringAsFixed(3)} €/L',
      );
      await _financial.recordOpportunity(
        vehicleId: vehicleId,
        featureCode: 'FUEL_OPTIMIZER',
        baselineAmount: referenceCost,
        proposedAmount: actualCost,
        calculationDetails: {
          'station_id': result.offer.stationId,
          'fuel_type': result.offer.fuelType,
          'volume_liters': volumeLiters,
          'station_price': result.offer.price,
          'reference_price': result.referencePrice,
          'detour_distance_km': result.detourDistanceKm,
          'detour_cost': result.detourCost,
          'confidence': result.priceAge != null && result.priceAge!.inHours < 6
              ? 'HIGH'
              : 'MEDIUM',
        },
        status: SavingStatus.confirmed,
        sourceReference: reference,
      );
    } on FinancialImpactException catch (error) {
      throw FuelOptimizerException(error.message);
    }
  }

  static double _decimal(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  static String _message(PostgrestException error) {
    if (error.message.toLowerCase().contains('relation')) {
      return 'Le profil financier doit être installé sur Supabase.';
    }
    return "Le profil de consommation n'a pas pu être enregistré.";
  }
}
