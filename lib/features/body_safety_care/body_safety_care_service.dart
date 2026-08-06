import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'body_safety_care_models.dart';

class BodySafetyCareService {
  BodySafetyCareService({
    SupabaseClient? client,
    VehicleService? vehicleService,
  }) : _client = client ?? Supabase.instance.client,
       _vehicleService = vehicleService ?? VehicleService();

  final SupabaseClient _client;
  final VehicleService _vehicleService;

  Future<List<Vehicle>> fetchVehicles() => _vehicleService.fetchVehicles();

  Future<List<BodySafetyCareSnapshot>> fetchRecent(String vehicleId) async {
    try {
      final rows = await _client
          .from('body_safety_checks')
          .select(
            'id, checked_at, check_context, care_score, care_level, completeness_percent',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List<dynamic>)
          .map(
            (row) => BodySafetyCareSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      throw const BodySafetyCareException(
        'Impossible de charger les contrôles récents.',
      );
    }
  }

  Future<void> save({
    required BodySafetyCareProfile profile,
    required BodySafetyCareAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('body_safety_checks').insert({
        ...profile.toMap(),
        'care_score': assessment.score,
        'care_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'urgent_count': assessment.urgentCount,
        'findings': [
          for (final finding in assessment.findings) finding.toMap(),
        ],
        'calculator_version': 'body-safety-care-v1',
      });
    } catch (_) {
      throw const BodySafetyCareException(
        'Impossible d’enregistrer ce contrôle de carrosserie et de sécurité.',
      );
    }
  }
}

class BodySafetyCareException implements Exception {
  const BodySafetyCareException(this.message);

  final String message;

  @override
  String toString() => message;
}
