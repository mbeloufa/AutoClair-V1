import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicle_care/vehicle_care_service.dart';
import 'sale_preparation_models.dart';

class SalePreparationException implements Exception {
  const SalePreparationException(this.message);

  final String message;
}

class SalePreparationService {
  final VehicleCareService _careService = VehicleCareService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<SalePreparationProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_sale_preparation_profiles')
          .select()
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return SalePreparationProfile.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return null;
      throw SalePreparationException(_message(error));
    } catch (_) {
      return null;
    }
  }

  Future<SalePreparationContext> loadContext({
    required String vehicleId,
    required int? currentMileage,
  }) async {
    try {
      final bundle = await _careService.loadBundle(vehicleId);
      final overdue = bundle.schedules
          .where(
            (schedule) => schedule.isOverdue(currentMileage: currentMileage),
          )
          .length;
      final confirmedEvents = bundle.dashboard.recentEvents
          .where((event) => event.userConfirmed)
          .length;
      return SalePreparationContext(
        completedDocumentCount: bundle.completedDocumentCount,
        saleReadinessScore: bundle.dashboard.health.saleReadinessScore,
        overdueMaintenanceCount: overdue,
        recentConfirmedEventCount: confirmedEvents,
      );
    } on VehicleCareException catch (error) {
      throw SalePreparationException(error.message);
    }
  }

  Future<void> saveProfile({
    required String vehicleId,
    required SalePreparationProfile profile,
  }) async {
    profile.validate();
    try {
      await _client.from('vehicle_sale_preparation_profiles').upsert({
        'vehicle_id': vehicleId,
        'buyer_type': profile.buyerType.databaseValue,
        'asking_price_eur': profile.askingPrice,
        'minimum_price_eur': profile.minimumPrice,
        'preparation_cost_eur': profile.preparationCost,
        'owns_vehicle': profile.ownsVehicle,
        'registration_available': profile.registrationAvailable,
        'coholders_ready': profile.coHoldersReady,
        'technical_control_date': _dateValue(profile.technicalControlDate),
        'technical_control_status':
            profile.technicalControlStatus.databaseValue,
        'csa_issued_at': _dateValue(profile.csaIssuedAt),
        'histovec_shared': profile.histovecShared,
        'invoices_available': profile.invoicesAvailable,
        'spare_key_count': profile.spareKeyCount,
        'cession_method': profile.cessionMethod.databaseValue,
      }, onConflict: 'vehicle_id');
    } on PostgrestException catch (error) {
      throw SalePreparationException(_message(error));
    }
  }

  Future<void> saveSnapshot({
    required String vehicleId,
    required SalePreparationProfile profile,
    required SalePreparationAssessment assessment,
  }) async {
    try {
      await _client.from('vehicle_sale_readiness_snapshots').insert({
        'vehicle_id': vehicleId,
        'readiness_score': assessment.score,
        'blocking_count': assessment.blockingCount,
        'warning_count': assessment.warningCount,
        'asking_price_eur': profile.askingPrice,
        'minimum_price_eur': profile.minimumPrice,
        'preparation_cost_eur': profile.preparationCost,
        'expected_net_at_asking_eur': assessment.expectedNetAtAsking,
        'expected_net_at_minimum_eur': assessment.expectedNetAtMinimum,
        'checklist': assessment.items
            .map((item) => item.toMap())
            .toList(growable: false),
      });
    } on PostgrestException catch (error) {
      throw SalePreparationException(_message(error));
    }
  }

  Future<List<SalePreparationSnapshot>> loadRecentSnapshots(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('vehicle_sale_readiness_snapshots')
          .select(
            'id,readiness_score,blocking_count,warning_count,'
            'expected_net_at_asking_eur,created_at',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(5);
      return (rows as List)
          .map(
            (row) => SalePreparationSnapshot.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return const [];
      throw SalePreparationException(_message(error));
    }
  }

  static String? _dateValue(DateTime? value) {
    if (value == null) return null;
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    final normalized = raw.toLowerCase();
    if (raw.contains('AUTH_REQUIRED') || normalized.contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule n’est plus accessible.';
    }
    if (normalized.contains('relation')) {
      return 'Le dossier de vente doit être installé sur Supabase.';
    }
    return 'Le dossier de vente n’a pas pu être enregistré.';
  }
}
