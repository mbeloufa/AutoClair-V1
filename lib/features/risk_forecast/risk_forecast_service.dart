import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'risk_forecast_models.dart';

class RiskForecastException implements Exception {
  const RiskForecastException(this.message);

  final String message;
}

class RiskForecastService {
  final VehicleService _vehicleService = VehicleService();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const RiskForecastException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    return userId;
  }

  Future<List<Vehicle>> loadVehicles() async {
    try {
      return await _vehicleService.fetchVehicles();
    } on VehicleServiceException catch (error) {
      throw RiskForecastException(error.message);
    }
  }

  Future<RiskForecastProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_risk_profiles')
          .select()
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return RiskForecastProfile.fromMap(Map<String, dynamic>.from(row));
    } on RiskForecastException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return null;
      throw RiskForecastException(_message(error));
    }
  }

  Future<void> saveProfile(RiskForecastProfile profile) async {
    profile.validate();
    try {
      await _client.from('vehicle_risk_profiles').upsert({
        'user_id': _userId,
        ...profile.toMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,vehicle_id');
    } on RiskForecastException {
      rethrow;
    } on PostgrestException catch (error) {
      throw RiskForecastException(_message(error));
    }
  }

  Future<void> saveAssessment({
    required RiskForecastProfile profile,
    required RiskForecastAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('vehicle_risk_assessments').insert({
        'user_id': _userId,
        'vehicle_id': profile.vehicleId,
        'risk_score': assessment.score,
        'risk_level': assessment.level.databaseValue,
        'data_confidence': assessment.dataConfidence.databaseValue,
        'factors': assessment.factors
            .map((factor) => factor.toMap())
            .toList(growable: false),
        'input_snapshot': profile.toMap(),
        'calculator_version': 'risk-forecast-v1',
      });
    } on RiskForecastException {
      rethrow;
    } on PostgrestException catch (error) {
      throw RiskForecastException(_message(error));
    }
  }

  Future<List<RiskForecastSnapshot>> loadRecentAssessments(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('vehicle_risk_assessments')
          .select('id,risk_score,risk_level,data_confidence,created_at')
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => RiskForecastSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on RiskForecastException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return const [];
      throw RiskForecastException(_message(error));
    }
  }

  static bool _isMissingRelation(PostgrestException error) {
    return error.message.toLowerCase().contains('relation');
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    final normalized = raw.toLowerCase();
    if (normalized.contains('jwt') || raw.contains('AUTH_REQUIRED')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (normalized.contains('relation')) {
      return 'L’analyse prédictive doit être installée sur Supabase.';
    }
    if (raw.contains('RISK_VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule ne vous appartient pas.';
    }
    return 'L’analyse des risques n’a pas pu être enregistrée.';
  }
}
