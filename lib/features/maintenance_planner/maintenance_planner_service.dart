import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicle_care/vehicle_care_models.dart';
import '../vehicle_care/vehicle_care_service.dart';
import '../vehicle_care/vehicle_event_catalog.dart';
import '../vehicle_care/vehicle_event_reminder.dart';
import 'maintenance_planner_models.dart';

class MaintenancePlannerException implements Exception {
  const MaintenancePlannerException(this.message);

  final String message;
}

class MaintenancePlannerService {
  final VehicleCareService _careService = VehicleCareService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<MaintenancePlannerProfile?> loadProfile(String vehicleId) async {
    try {
      final row = await _client
          .from('vehicle_maintenance_planner_profiles')
          .select(
            'annual_mileage_km,budget_buffer_percent,reminder_days_before',
          )
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return MaintenancePlannerProfile.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('relation')) return null;
      throw MaintenancePlannerException(_message(error));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile({
    required String vehicleId,
    required MaintenancePlannerProfile profile,
  }) async {
    profile.validate();
    try {
      await _client.from('vehicle_maintenance_planner_profiles').upsert({
        'vehicle_id': vehicleId,
        'annual_mileage_km': profile.annualMileageKm,
        'budget_buffer_percent': profile.budgetBufferPercent,
        'reminder_days_before': profile.reminderDaysBefore,
      }, onConflict: 'vehicle_id');
    } on PostgrestException catch (error) {
      throw MaintenancePlannerException(_message(error));
    }
  }

  Future<List<VehicleMaintenanceSchedule>> loadSchedules(
    String vehicleId,
  ) async {
    try {
      final bundle = await _careService.loadBundle(vehicleId);
      return bundle.schedules;
    } on VehicleCareException catch (error) {
      throw MaintenancePlannerException(error.message);
    }
  }

  Future<int> createIndicativePlan(String vehicleId) async {
    try {
      return await _careService.applyDefaultMaintenancePlan(vehicleId);
    } on VehicleCareException catch (error) {
      throw MaintenancePlannerException(error.message);
    }
  }

  Future<void> planInVehicleLog({
    required String vehicleId,
    required MaintenanceForecastItem item,
    required MaintenancePlannerProfile profile,
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final dueDate = item.projectedDate;
    final plannedDate = dueDate == null || !dueDate.isAfter(reference)
        ? reference.add(const Duration(days: 7))
        : dueDate;
    final classification = VehicleEventCatalog.classify(
      item.schedule.title,
      fallbackEventType: item.schedule.scheduleType,
    );
    final reminderDays = _effectiveReminderDays(
      requestedDays: profile.reminderDaysBefore,
      plannedDate: plannedDate,
      now: reference,
    );
    final estimated = item.costRange.withBuffer(profile.budgetBufferPercent);
    final description =
        'Estimation AutoClair : ${estimated.minimum.toStringAsFixed(0)} à '
        '${estimated.maximum.toStringAsFixed(0)} €. '
        'À confirmer avec le carnet constructeur et un professionnel.';

    try {
      await _careService.recordEvent(
        vehicleId: vehicleId,
        eventType: classification.subcategory.eventType,
        categoryCode: classification.category.code,
        subcategoryCode: classification.subcategory.code,
        title: item.schedule.title,
        occurredAt: plannedDate,
        status: 'PLANNED',
        mileage: item.projectedMileage,
        description: description,
        reminderEnabled: true,
        reminderDaysBefore: reminderDays,
      );
    } on VehicleCareException catch (error) {
      throw MaintenancePlannerException(error.message);
    }
  }

  static int _effectiveReminderDays({
    required int requestedDays,
    required DateTime plannedDate,
    required DateTime now,
  }) {
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(plannedDate.year, plannedDate.month, plannedDate.day);
    final availableDays = end.difference(start).inDays;
    final candidates = supportedVehicleEventReminderDays
        .where((days) => days <= requestedDays && days <= availableDays)
        .toList(growable: false);
    return candidates.isEmpty ? 1 : candidates.last;
  }

  static String _message(PostgrestException error) {
    final raw = error.message;
    if (raw.contains('AUTH_REQUIRED') || raw.toLowerCase().contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('VEHICLE_FORBIDDEN')) {
      return 'Ce véhicule n’est plus accessible.';
    }
    if (raw.toLowerCase().contains('relation')) {
      return 'Le planificateur d’entretien doit être installé sur Supabase.';
    }
    return 'Le planificateur d’entretien n’a pas pu enregistrer ces données.';
  }
}
