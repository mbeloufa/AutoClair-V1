import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicle_care/vehicle_care_service.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'accident_assistant_models.dart';

class AccidentAssistantException implements Exception {
  const AccidentAssistantException(this.message);

  final String message;
}

class AccidentAssistantService {
  final VehicleService _vehicleService = VehicleService();
  final VehicleCareService _careService = VehicleCareService();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AccidentAssistantException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    return userId;
  }

  Future<List<Vehicle>> loadVehicles() async {
    try {
      return await _vehicleService.fetchVehicles();
    } on VehicleServiceException catch (error) {
      throw AccidentAssistantException(error.message);
    }
  }

  Future<AccidentAssistantProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_accident_profiles')
          .select()
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return AccidentAssistantProfile.fromMap(Map<String, dynamic>.from(row));
    } on AccidentAssistantException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return null;
      throw AccidentAssistantException(_message(error));
    }
  }

  Future<void> saveProfile(AccidentAssistantProfile profile) async {
    profile.validate();
    try {
      await _client.from('vehicle_accident_profiles').upsert({
        'user_id': _userId,
        ...profile.toMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,vehicle_id');
    } on AccidentAssistantException {
      rethrow;
    } on PostgrestException catch (error) {
      throw AccidentAssistantException(_message(error));
    }
  }

  Future<void> saveCase({
    required AccidentAssistantProfile profile,
    required AccidentCaseInput input,
    required AccidentAssessment assessment,
    required String vehicleLabel,
  }) async {
    profile.validate();
    input.validate();
    try {
      final event = await _careService.recordEvent(
        vehicleId: input.vehicleId,
        eventType: 'ACCIDENT',
        categoryCode: 'ADMINISTRATIVE',
        subcategoryCode: 'ACCIDENT_CLAIM',
        title: 'Sinistre automobile',
        occurredAt: input.occurredAt,
        status: 'COMPLETED',
        description: assessment.buildShareSummary(
          input: input,
          vehicleLabel: vehicleLabel,
        ),
      );

      await _client.from('vehicle_accident_cases').insert({
        'user_id': _userId,
        ...input.toMap(),
        'action_level': assessment.actionLevel.databaseValue,
        'readiness_score': assessment.score,
        'econstat_eligible': assessment.eConstatEligible,
        'paper_report_required': assessment.paperReportRequired,
        'declaration_due_date': _dateValue(assessment.declarationDueDate),
        'checklist': assessment.items
            .map((item) => item.toMap())
            .toList(growable: false),
        'timeline_event_id': event.eventId,
      });
    } on AccidentAssistantException {
      rethrow;
    } on VehicleCareException catch (error) {
      throw AccidentAssistantException(error.message);
    } on PostgrestException catch (error) {
      throw AccidentAssistantException(_message(error));
    }
  }

  Future<List<AccidentCaseSnapshot>> loadRecentCases(String vehicleId) async {
    try {
      final rows = await _client
          .from('vehicle_accident_cases')
          .select(
            'id,occurred_at,action_level,readiness_score,insurer_notified',
          )
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .order('occurred_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => AccidentCaseSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on AccidentAssistantException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return const [];
      throw AccidentAssistantException(_message(error));
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
      return 'L’assistant accident doit être installé sur Supabase.';
    }
    if (raw.contains('ACCIDENT_VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule ne vous appartient pas.';
    }
    return 'Le dossier accident n’a pas pu être enregistré.';
  }
}
