import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'tire_care_models.dart';

class TireCareService {
  TireCareService({SupabaseClient? client, VehicleService? vehicleService})
    : _client = client ?? Supabase.instance.client,
      _vehicleService = vehicleService ?? VehicleService();

  final SupabaseClient _client;
  final VehicleService _vehicleService;

  Future<List<Vehicle>> fetchVehicles() => _vehicleService.fetchVehicles();

  Future<List<TireCareSnapshot>> fetchRecent(String vehicleId) async {
    try {
      final rows = await _client
          .from('tire_care_checks')
          .select(
            'id, checked_at, check_context, care_score, care_level, completeness_percent',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) =>
                TireCareSnapshot.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      throw const TireCareException(
        'Impossible de charger les contrôles récents.',
      );
    }
  }

  Future<void> save({
    required TireCareProfile profile,
    required TireCareAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('tire_care_checks').insert({
        ...profile.toMap(),
        'care_score': assessment.score,
        'care_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'urgent_count': assessment.urgentCount,
        'findings': [
          for (final finding in assessment.findings) finding.toMap(),
        ],
        'calculator_version': 'tire-care-v1',
      });
    } catch (_) {
      throw const TireCareException(
        'Impossible d’enregistrer ce contrôle des pneus.',
      );
    }
  }
}

class TireCareException implements Exception {
  const TireCareException(this.message);

  final String message;

  @override
  String toString() => message;
}
