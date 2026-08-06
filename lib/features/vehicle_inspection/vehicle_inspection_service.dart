import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';
import 'vehicle_inspection_models.dart';

class VehicleInspectionException implements Exception {
  const VehicleInspectionException(this.message);

  final String message;
}

class VehicleInspectionService {
  final VehicleService _vehicleService = VehicleService();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const VehicleInspectionException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    return userId;
  }

  Future<List<Vehicle>> loadVehicles() async {
    try {
      return await _vehicleService.fetchVehicles();
    } on VehicleServiceException catch (error) {
      throw VehicleInspectionException(error.message);
    }
  }

  Future<void> saveInspection({
    required VehicleInspectionProfile profile,
    required VehicleInspectionAssessment assessment,
  }) async {
    profile.validate();
    try {
      await _client.from('vehicle_inspections').insert({
        'user_id': _userId,
        'vehicle_id': profile.vehicleId,
        'purpose': profile.purpose.databaseValue,
        'condition_score': assessment.score,
        'condition_level': assessment.level.databaseValue,
        'completeness_percent': assessment.completenessPercent,
        'immediate_action': assessment.immediateAction,
        'road_test_completed': profile.roadTestCompleted,
        'photos_available': profile.photosAvailable,
        'professional_check_planned': profile.professionalCheckPlanned,
        'checks': profile.toMap()['checks'],
        'findings': assessment.findings
            .map((finding) => finding.toMap())
            .toList(growable: false),
        'calculator_version': 'vehicle-inspection-v1',
      });
    } on VehicleInspectionException {
      rethrow;
    } on PostgrestException catch (error) {
      throw VehicleInspectionException(_message(error));
    }
  }

  Future<List<VehicleInspectionSnapshot>> loadRecentInspections(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('vehicle_inspections')
          .select(
            'id,purpose,condition_score,condition_level,completeness_percent,created_at',
          )
          .eq('user_id', _userId)
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => VehicleInspectionSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on VehicleInspectionException {
      rethrow;
    } on PostgrestException catch (error) {
      if (_isMissingRelation(error)) return const [];
      throw VehicleInspectionException(_message(error));
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
      return 'L’inspection guidée doit être installée sur Supabase.';
    }
    if (raw.contains('INSPECTION_VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule ne vous appartient pas.';
    }
    return 'L’inspection n’a pas pu être enregistrée.';
  }
}
