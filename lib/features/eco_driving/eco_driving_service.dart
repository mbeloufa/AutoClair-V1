import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/finance/financial_impact_service.dart';
import '../../core/finance/saving_status.dart';
import 'eco_driving_models.dart';

class EcoDrivingServiceException implements Exception {
  const EcoDrivingServiceException(this.message);

  final String message;
}

class EcoDrivingSaveResult {
  const EcoDrivingSaveResult({required this.savingOpportunityRecorded});

  final bool savingOpportunityRecorded;
}

class EcoDrivingService {
  final FinancialImpactService _financial = FinancialImpactService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<EcoDrivingProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_eco_driving_profiles')
          .select(
            'energy_type,consumption_per_100km,energy_price,'
            'potential_gain_percent',
          )
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      return row == null ? null : EcoDrivingProfile.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return null;
      throw EcoDrivingServiceException(_message(error));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile({
    required String vehicleId,
    required EcoDrivingProfile profile,
  }) async {
    _validateProfile(profile);
    try {
      await _client.from('vehicle_eco_driving_profiles').upsert({
        'vehicle_id': vehicleId,
        'energy_type': profile.energyType.databaseValue,
        'consumption_per_100km': profile.consumptionPer100Km,
        'energy_price': profile.energyPrice,
        'potential_gain_percent': profile.potentialGainPercent,
      }, onConflict: 'vehicle_id');
    } on PostgrestException catch (error) {
      throw EcoDrivingServiceException(_message(error));
    }
  }

  Future<EcoDrivingSaveResult> saveSession({
    required String vehicleId,
    required EcoDrivingProfile profile,
    required EcoDrivingSessionSummary summary,
  }) async {
    _validateProfile(profile);
    try {
      final row = await _client
          .from('eco_driving_sessions')
          .insert({
            'vehicle_id': vehicleId,
            'started_at': summary.startedAt.toIso8601String(),
            'ended_at': summary.endedAt.toIso8601String(),
            'duration_seconds': summary.durationSeconds,
            'moving_seconds': summary.movingSeconds,
            'idle_seconds': summary.idleSeconds,
            'distance_km': summary.distanceKm,
            'average_speed_kph': summary.averageSpeedKph,
            'harsh_acceleration_count': summary.harshAccelerationCount,
            'harsh_braking_count': summary.harshBrakingCount,
            'accepted_sample_count': summary.acceptedSampleCount,
            'discarded_sample_count': summary.discardedSampleCount,
            'score': summary.score,
            'baseline_energy_cost': summary.baselineEnergyCost,
            'potential_saving': summary.potentialSaving,
          })
          .select('id')
          .single();

      var recorded = false;
      if (summary.isMeaningful && summary.potentialSaving > 0.01) {
        final sessionId = row['id'].toString();
        try {
          await _financial.recordOpportunity(
            vehicleId: vehicleId,
            featureCode: 'ECO_DRIVING_COACH',
            baselineAmount: summary.baselineEnergyCost,
            proposedAmount:
                summary.baselineEnergyCost - summary.potentialSaving,
            calculationDetails: {
              'session_id': sessionId,
              'distance_km': summary.distanceKm,
              'duration_seconds': summary.durationSeconds,
              'score': summary.score,
              'harsh_acceleration_count': summary.harshAccelerationCount,
              'harsh_braking_count': summary.harshBrakingCount,
              'idle_seconds': summary.idleSeconds,
              'accepted_sample_count': summary.acceptedSampleCount,
              'discarded_sample_count': summary.discardedSampleCount,
              'confidence': summary.acceptedSampleCount >= 15
                  ? 'MEDIUM'
                  : 'LOW',
            },
            status: SavingStatus.detected,
            sourceReference: 'eco-driving-$sessionId',
          );
          recorded = true;
        } on FinancialImpactException {
          recorded = false;
        }
      }

      return EcoDrivingSaveResult(savingOpportunityRecorded: recorded);
    } on PostgrestException catch (error) {
      throw EcoDrivingServiceException(_message(error));
    } catch (_) {
      throw const EcoDrivingServiceException(
        'Le bilan du trajet n’a pas pu être enregistré.',
      );
    }
  }

  Future<List<EcoDrivingSessionRecord>> fetchRecentSessions(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('eco_driving_sessions')
          .select(
            'id,started_at,duration_seconds,distance_km,score,'
            'potential_saving',
          )
          .eq('vehicle_id', vehicleId)
          .order('started_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) => EcoDrivingSessionRecord.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return const [];
      throw EcoDrivingServiceException(_message(error));
    } catch (_) {
      return const [];
    }
  }

  static void _validateProfile(EcoDrivingProfile profile) {
    if (profile.consumptionPer100Km <= 0 ||
        profile.consumptionPer100Km > 100 ||
        profile.energyPrice < 0 ||
        profile.energyPrice > 10 ||
        profile.potentialGainPercent < 0 ||
        profile.potentialGainPercent > 15) {
      throw const EcoDrivingServiceException(
        'Le profil d’écoconduite contient une valeur invalide.',
      );
    }
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    if (raw.contains('AUTH_REQUIRED') || raw.toLowerCase().contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule n’est plus accessible.';
    }
    if (raw.toLowerCase().contains('relation')) {
      return 'Le coach d’écoconduite doit être installé sur Supabase.';
    }
    return 'Le coach d’écoconduite n’a pas pu enregistrer ces données.';
  }
}
