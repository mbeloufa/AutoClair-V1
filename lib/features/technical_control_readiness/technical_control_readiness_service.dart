import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'technical_control_readiness_models.dart';

class TechnicalControlReadinessService {
  TechnicalControlReadinessService({
    SupabaseClient? client,
    VehicleService? vehicleService,
  }) : _client = client ?? Supabase.instance.client,
       _vehicleService = vehicleService ?? VehicleService();

  final SupabaseClient _client;
  final VehicleService _vehicleService;

  Future<List<Vehicle>> fetchVehicles() => _vehicleService.fetchVehicles();

  Future<List<TechnicalControlReadinessSnapshot>> fetchRecent(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('technical_control_readiness_checks')
          .select(
            'id, planned_date, visit_context, readiness_score, readiness_level, completeness_percent',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) => TechnicalControlReadinessSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      throw const TechnicalControlReadinessException(
        'Impossible de charger les préparations récentes.',
      );
    }
  }

  Future<void> save({
    required TechnicalControlReadinessProfile profile,
    required TechnicalControlReadinessAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('technical_control_readiness_checks').insert({
        ...profile.toMap(),
        'readiness_score': assessment.score,
        'readiness_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'blocking_count': assessment.blockingCount,
        'findings': [
          for (final finding in assessment.findings) finding.toMap(),
        ],
        'calculator_version': 'technical-control-readiness-v1',
      });
    } catch (_) {
      throw const TechnicalControlReadinessException(
        'Impossible d’enregistrer cette préparation.',
      );
    }
  }
}

class TechnicalControlReadinessException implements Exception {
  const TechnicalControlReadinessException(this.message);

  final String message;

  @override
  String toString() => message;
}
