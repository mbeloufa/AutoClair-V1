import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicle_care/vehicle_care_service.dart';
import 'breakdown_assistant_models.dart';

class BreakdownAssistantException implements Exception {
  const BreakdownAssistantException(this.message);

  final String message;
}

class BreakdownAssistantService {
  final VehicleCareService _careService = VehicleCareService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<BreakdownAssistantProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_breakdown_profiles')
          .select(
            'assistance_provider,assistance_phone,contract_reference,assistance_zero_km',
          )
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return BreakdownAssistantProfile.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return null;
      throw BreakdownAssistantException(_message(error));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile({
    required String vehicleId,
    required BreakdownAssistantProfile profile,
  }) async {
    profile.validate();
    try {
      await _client.from('vehicle_breakdown_profiles').upsert({
        'vehicle_id': vehicleId,
        'assistance_provider': _nullIfEmpty(profile.assistanceProvider),
        'assistance_phone': _nullIfEmpty(profile.assistancePhone),
        'contract_reference': _nullIfEmpty(profile.contractReference),
        'assistance_zero_km': profile.assistanceZeroKm,
      }, onConflict: 'vehicle_id');
    } on PostgrestException catch (error) {
      throw BreakdownAssistantException(_message(error));
    }
  }

  Future<List<BreakdownCaseSummary>> loadRecentCases(String vehicleId) async {
    try {
      final rows = await _client
          .from('vehicle_breakdown_cases')
          .select(
            'id,occurred_at,action_level,location_type,symptom_codes,summary',
          )
          .eq('vehicle_id', vehicleId)
          .order('occurred_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => BreakdownCaseSummary.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return const [];
      throw BreakdownAssistantException(_message(error));
    } catch (_) {
      return const [];
    }
  }

  Future<String?> recordInVehicleLog({
    required String vehicleId,
    required BreakdownAssessment assessment,
    required String summary,
    required DateTime occurredAt,
    int? mileage,
  }) async {
    try {
      final result = await _careService.recordEvent(
        vehicleId: vehicleId,
        eventType: assessment.eventType,
        categoryCode: assessment.categoryCode,
        subcategoryCode: assessment.subcategoryCode,
        title: 'Incident ou panne',
        occurredAt: occurredAt,
        status: 'COMPLETED',
        mileage: mileage,
        description: summary,
      );
      return result.eventId;
    } on VehicleCareException catch (error) {
      throw BreakdownAssistantException(error.message);
    }
  }

  Future<void> saveCase({
    required String vehicleId,
    required BreakdownAssessmentInput input,
    required BreakdownAssessment assessment,
    required String summary,
    required DateTime occurredAt,
    String? timelineEventId,
  }) async {
    try {
      await _client.from('vehicle_breakdown_cases').insert({
        'vehicle_id': vehicleId,
        'occurred_at': occurredAt.toIso8601String(),
        'location_type': input.locationType.databaseValue,
        'action_level': assessment.actionLevel.databaseValue,
        'symptom_codes': assessment.symptomCodes,
        'safety_flags': <String, dynamic>{
          'safely_parked': input.safelyParked,
          'vehicle_in_traffic_lane': input.vehicleInTrafficLane,
          'injured_person': input.injuredPerson,
          'vehicle_can_move': input.vehicleCanMove,
        },
        'summary': summary,
        'timeline_event_id': timelineEventId,
      });
    } on PostgrestException catch (error) {
      throw BreakdownAssistantException(_message(error));
    }
  }

  static String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    final normalized = raw.toLowerCase();
    if (raw.contains('AUTH_REQUIRED') || normalized.contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule n’est plus accessible.';
    }
    if (normalized.contains('relation')) {
      return 'L’assistant panne doit être installé sur Supabase.';
    }
    return 'L’assistant panne n’a pas pu enregistrer ces informations.';
  }
}
