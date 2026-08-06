import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'trip_readiness_models.dart';

class TripReadinessException implements Exception {
  const TripReadinessException(this.message);

  final String message;
}

class TripReadinessService {
  final VehicleService _vehicleService = VehicleService();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const TripReadinessException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    return userId;
  }

  Future<List<Vehicle>> loadVehicles() async {
    try {
      return await _vehicleService.fetchVehicles();
    } on VehicleServiceException catch (error) {
      throw TripReadinessException(error.message);
    }
  }

  Future<void> saveCheck({
    required TripReadinessProfile profile,
    required TripReadinessAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('trip_readiness_checks').insert({
        'user_id': _userId,
        'vehicle_id': profile.vehicleId,
        'departure_date': profile.toMap()['departure_date'],
        'purpose': profile.purpose.databaseValue,
        'readiness_score': assessment.score,
        'readiness_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'blocking_count': assessment.blockingCount,
        'long_distance': profile.longDistance,
        'towing': profile.towing,
        'cold_conditions': profile.coldConditions,
        'young_passengers': profile.youngPassengers,
        'breakdown_coverage_known': profile.breakdownCoverageKnown,
        'checks': profile.toMap()['checks'],
        'findings': assessment.findings
            .map((finding) => finding.toMap())
            .toList(growable: false),
        'calculator_version': 'trip-readiness-v1',
      });
    } on TripReadinessException {
      rethrow;
    } on PostgrestException catch (error) {
      throw TripReadinessException(_message(error));
    }
  }

  Future<List<TripReadinessSnapshot>> loadRecentChecks(String vehicleId) async {
    try {
      final rows = await _client
          .from('trip_readiness_checks')
          .select(
            'id,departure_date,purpose,readiness_score,readiness_level,completeness_percent,created_at',
          )
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => TripReadinessSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on TripReadinessException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return const [];
      throw TripReadinessException(_message(error));
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
      return 'La préparation de départ doit être installée sur Supabase.';
    }
    return 'La préparation n’a pas pu être enregistrée.';
  }
}
