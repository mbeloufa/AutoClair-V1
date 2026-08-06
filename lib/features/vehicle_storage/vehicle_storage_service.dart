import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'vehicle_storage_models.dart';

class VehicleStorageService {
  VehicleStorageService({
    SupabaseClient? client,
    VehicleService? vehicleService,
  }) : _client = client ?? Supabase.instance.client,
       _vehicleService = vehicleService ?? VehicleService();

  final SupabaseClient _client;
  final VehicleService _vehicleService;

  Future<List<Vehicle>> fetchVehicles() => _vehicleService.fetchVehicles();

  Future<List<VehicleStorageSnapshot>> fetchRecent(String vehicleId) async {
    try {
      final rows = await _client
          .from('vehicle_storage_checks')
          .select(
            'id, planned_start_date, planned_weeks, scenario, readiness_score, readiness_level, completeness_percent',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) => VehicleStorageSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      throw const VehicleStorageException(
        'Impossible de charger les immobilisations récentes.',
      );
    }
  }

  Future<void> save({
    required VehicleStorageProfile profile,
    required VehicleStorageAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('vehicle_storage_checks').insert({
        ...profile.toMap(),
        'readiness_score': assessment.score,
        'readiness_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'blocking_count': assessment.blockingCount,
        'findings': [
          for (final finding in assessment.findings) finding.toMap(),
        ],
        'calculator_version': 'vehicle-storage-v1',
      });
    } catch (_) {
      throw const VehicleStorageException(
        'Impossible d’enregistrer cette préparation.',
      );
    }
  }
}

class VehicleStorageException implements Exception {
  const VehicleStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
