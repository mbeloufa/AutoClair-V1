import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'workshop_visit_preparation_models.dart';

class WorkshopVisitPreparationService {
  WorkshopVisitPreparationService({
    SupabaseClient? client,
    VehicleService? vehicleService,
  }) : _client = client ?? Supabase.instance.client,
       _vehicleService = vehicleService ?? VehicleService();

  final SupabaseClient _client;
  final VehicleService _vehicleService;

  Future<List<Vehicle>> fetchVehicles() => _vehicleService.fetchVehicles();

  Future<List<WorkshopVisitPreparationSnapshot>> fetchRecent(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('workshop_visit_preparations')
          .select(
            'id, planned_date, visit_reason, preparation_score, preparation_level, completeness_percent',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) => WorkshopVisitPreparationSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      throw const WorkshopVisitPreparationException(
        'Impossible de charger les préparations récentes.',
      );
    }
  }

  Future<void> save({
    required WorkshopVisitPreparationProfile profile,
    required WorkshopVisitPreparationAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('workshop_visit_preparations').insert({
        ...profile.toMap(),
        'preparation_score': assessment.score,
        'preparation_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'urgent_count': assessment.urgentCount,
        'findings': [
          for (final finding in assessment.findings) finding.toMap(),
        ],
        'calculator_version': 'workshop-visit-preparation-v1',
      });
    } catch (_) {
      throw const WorkshopVisitPreparationException(
        'Impossible d’enregistrer cette préparation.',
      );
    }
  }
}

class WorkshopVisitPreparationException implements Exception {
  const WorkshopVisitPreparationException(this.message);

  final String message;

  @override
  String toString() => message;
}
