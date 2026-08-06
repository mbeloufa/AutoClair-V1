import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'lease_return_models.dart';

class LeaseReturnService {
  LeaseReturnService({SupabaseClient? client, VehicleService? vehicleService})
    : _client = client ?? Supabase.instance.client,
      _vehicleService = vehicleService ?? VehicleService();

  final SupabaseClient _client;
  final VehicleService _vehicleService;

  Future<List<Vehicle>> fetchVehicles() => _vehicleService.fetchVehicles();

  Future<List<LeaseReturnSnapshot>> fetchRecent(String vehicleId) async {
    try {
      final rows = await _client
          .from('lease_return_preparations')
          .select(
            'id, prepared_at, preparation_context, preparation_score, preparation_level, completeness_percent',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) => LeaseReturnSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      throw const LeaseReturnException(
        'Impossible de charger les préparations récentes.',
      );
    }
  }

  Future<void> save({
    required LeaseReturnProfile profile,
    required LeaseReturnAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('lease_return_preparations').insert({
        ...profile.toMap(),
        'preparation_score': assessment.score,
        'preparation_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'urgent_count': assessment.urgentCount,
        'findings': [
          for (final finding in assessment.findings) finding.toMap(),
        ],
        'calculator_version': 'lease-return-v1',
      });
    } catch (_) {
      throw const LeaseReturnException(
        'Impossible d’enregistrer cette préparation de restitution.',
      );
    }
  }
}

class LeaseReturnException implements Exception {
  const LeaseReturnException(this.message);

  final String message;

  @override
  String toString() => message;
}
