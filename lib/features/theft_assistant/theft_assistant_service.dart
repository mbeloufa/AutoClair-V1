import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicle_care/vehicle_care_service.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'theft_assistant_models.dart';

class TheftAssistantException implements Exception {
  const TheftAssistantException(this.message);

  final String message;
}

class TheftAssistantService {
  final VehicleService _vehicleService = VehicleService();
  final VehicleCareService _careService = VehicleCareService();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const TheftAssistantException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    return userId;
  }

  Future<List<Vehicle>> loadVehicles() async {
    try {
      return await _vehicleService.fetchVehicles();
    } on VehicleServiceException catch (error) {
      throw TheftAssistantException(error.message);
    }
  }

  Future<TheftAssistantProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_theft_profiles')
          .select()
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return TheftAssistantProfile.fromMap(Map<String, dynamic>.from(row));
    } on TheftAssistantException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return null;
      throw TheftAssistantException(_message(error));
    }
  }

  Future<void> saveProfile(TheftAssistantProfile profile) async {
    profile.validate();
    try {
      await _client.from('vehicle_theft_profiles').upsert({
        'user_id': _userId,
        ...profile.toMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,vehicle_id');
    } on TheftAssistantException {
      rethrow;
    } on PostgrestException catch (error) {
      throw TheftAssistantException(_message(error));
    }
  }

  Future<void> saveCase({
    required TheftAssistantProfile profile,
    required TheftCaseInput input,
    required TheftAssessment assessment,
    required String vehicleLabel,
  }) async {
    profile.validate();
    input.validate();
    try {
      final event = await _careService.recordEvent(
        vehicleId: input.vehicleId,
        eventType: 'INSURANCE',
        categoryCode: 'ADMINISTRATIVE',
        subcategoryCode: 'INSURANCE',
        title: input.incidentType.timelineTitle,
        occurredAt: input.occurredAt,
        status: 'COMPLETED',
        description: assessment.buildShareSummary(
          input: input,
          vehicleLabel: vehicleLabel,
        ),
      );

      await _client.from('vehicle_theft_cases').insert({
        'user_id': _userId,
        ...input.toMap(),
        'action_level': assessment.actionLevel.databaseValue,
        'readiness_score': assessment.score,
        'online_complaint_eligible': assessment.onlineComplaintEligible,
        'declaration_due_date': _dateValue(assessment.declarationDueDate),
        'checklist': assessment.items
            .map((item) => item.toMap())
            .toList(growable: false),
        'timeline_event_id': event.eventId,
      });
    } on TheftAssistantException {
      rethrow;
    } on VehicleCareException catch (error) {
      throw TheftAssistantException(error.message);
    } on PostgrestException catch (error) {
      throw TheftAssistantException(_message(error));
    }
  }

  Future<List<TheftCaseSnapshot>> loadRecentCases(String vehicleId) async {
    try {
      final rows = await _client
          .from('vehicle_theft_cases')
          .select(
            'id,occurred_at,incident_type,action_level,'
            'readiness_score,insurer_notified',
          )
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .order('occurred_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => TheftCaseSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on TheftAssistantException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return const [];
      throw TheftAssistantException(_message(error));
    }
  }

  static bool _isMissingRelation(PostgrestException error) {
    return error.message.toLowerCase().contains('relation');
  }

  static String _dateValue(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    final normalized = raw.toLowerCase();
    if (normalized.contains('jwt') || raw.contains('AUTH_REQUIRED')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (normalized.contains('relation')) {
      return 'L’assistant vol doit être installé sur Supabase.';
    }
    if (raw.contains('THEFT_VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule ne vous appartient pas.';
    }
    return 'Le dossier vol ou dégradation n’a pas pu être enregistré.';
  }
}
