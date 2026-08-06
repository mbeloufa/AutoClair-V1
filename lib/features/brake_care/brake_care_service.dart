import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'brake_care_models.dart';

class BrakeCareService {
  BrakeCareService({SupabaseClient? client, VehicleService? vehicleService})
    : _client = client ?? Supabase.instance.client,
      _vehicleService = vehicleService ?? VehicleService();

  final SupabaseClient _client;
  final VehicleService _vehicleService;

  Future<List<Vehicle>> fetchVehicles() => _vehicleService.fetchVehicles();

  Future<List<BrakeCareSnapshot>> fetchRecent(String vehicleId) async {
    try {
      final rows = await _client
          .from('brake_care_checks')
          .select(
            'id, checked_at, check_context, care_score, care_level, completeness_percent',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) => BrakeCareSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      throw const BrakeCareException(
        'Impossible de charger les contrôles récents.',
      );
    }
  }

  Future<void> save({
    required BrakeCareProfile profile,
    required BrakeCareAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('brake_care_checks').insert({
        ...profile.toMap(),
        'care_score': assessment.score,
        'care_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'urgent_count': assessment.urgentCount,
        'findings': [
          for (final finding in assessment.findings) finding.toMap(),
        ],
        'calculator_version': 'brake-care-v1',
      });
    } catch (_) {
      throw const BrakeCareException(
        'Impossible d’enregistrer ce contrôle de freinage et de tenue de route.',
      );
    }
  }
}

class BrakeCareException implements Exception {
  const BrakeCareException(this.message);

  final String message;

  @override
  String toString() => message;
}
