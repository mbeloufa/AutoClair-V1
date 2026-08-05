import 'package:supabase_flutter/supabase_flutter.dart';

import '../vehicle_care/vehicle_care_service.dart';
import 'compliance_models.dart';

class ComplianceException implements Exception {
  const ComplianceException(this.message);

  final String message;
}

class ComplianceService {
  final VehicleCareService _careService = VehicleCareService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<ComplianceOverview> loadOverview(String vehicleId) async {
    try {
      final manualRows = await _client
          .from('vehicle_compliance_items')
          .select(
            'id,item_type,title,message,status,priority,source_type,due_date,'
            'source_url,confidence',
          )
          .eq('vehicle_id', vehicleId)
          .neq('status', 'DISMISSED')
          .order('due_date', ascending: true, nullsFirst: false);

      final items = (manualRows as List)
          .map(
            (row) =>
                ComplianceItem.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

      try {
        final bundle = await _careService.loadBundle(vehicleId);
        for (final recall in bundle.dashboard.recalls) {
          if (!recall.requiresAttention || recall.matchScore < 0.80) continue;
          items.add(
            ComplianceItem(
              id: 'recall-${recall.matchId}',
              type: 'RECALL',
              title: recall.title,
              message: recall.matchScore >= 0.90
                  ? 'Compatibilité forte. Confirmez avec le VIN auprès du constructeur.'
                  : 'Votre véhicule pourrait être concerné. Vérifiez avec le VIN.',
              status: 'ACTIVE',
              priority: recall.matchScore >= 0.90 ? 'HIGH' : 'MEDIUM',
              sourceType: 'VEHICLE_RECALL_MATCH',
              dueDate: recall.publicationDate,
              sourceUrl: recall.recallUrl,
              confidence: recall.matchScore,
            ),
          );
        }
        for (final schedule in bundle.schedules) {
          if (schedule.scheduleType != 'MAINTENANCE') continue;
          items.add(
            ComplianceItem(
              id: 'schedule-${schedule.id}',
              type: 'MAINTENANCE',
              title: schedule.title,
              message: schedule.reason.isEmpty
                  ? 'Échéance issue du carnet AutoClair.'
                  : schedule.reason,
              status: 'ACTIVE',
              priority: schedule.priority,
              sourceType: schedule.sourceType,
              dueDate: schedule.dueDate,
            ),
          );
        }
      } catch (_) {
        // Les échéances manuelles restent disponibles si le carnet est indisponible.
      }

      items.sort((left, right) {
        if (left.isUrgent != right.isUrgent) return left.isUrgent ? -1 : 1;
        final leftDate = left.dueDate ?? DateTime(9999);
        final rightDate = right.dueDate ?? DateTime(9999);
        return leftDate.compareTo(rightDate);
      });
      return ComplianceOverview(items: List.unmodifiable(items));
    } on PostgrestException catch (error) {
      throw ComplianceException(_message(error));
    } catch (_) {
      throw const ComplianceException(
        "Le centre de conformité n'a pas pu être chargé.",
      );
    }
  }

  Future<void> saveManualItem({
    required String vehicleId,
    required String type,
    required String title,
    required DateTime dueDate,
    String? message,
  }) async {
    try {
      await _client.from('vehicle_compliance_items').insert({
        'vehicle_id': vehicleId,
        'item_type': type,
        'title': title.trim(),
        'message': message?.trim(),
        'due_date': _dateOnly(dueDate),
        'status': 'ACTIVE',
        'priority': 'MEDIUM',
        'source_type': 'MANUAL',
      });
    } on PostgrestException catch (error) {
      throw ComplianceException(_message(error));
    }
  }

  Future<void> completeItem(String itemId) async {
    if (itemId.startsWith('recall-') || itemId.startsWith('schedule-')) {
      throw const ComplianceException(
        'Traitez cet élément depuis le carnet du véhicule.',
      );
    }
    try {
      await _client
          .from('vehicle_compliance_items')
          .update({
            'status': 'COMPLETED',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId);
    } on PostgrestException catch (error) {
      throw ComplianceException(_message(error));
    }
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _message(PostgrestException error) {
    if (error.message.toLowerCase().contains('relation')) {
      return 'Le centre de conformité doit être installé sur Supabase.';
    }
    if (error.message.toLowerCase().contains('policy')) {
      return "Vous n'avez pas accès à ces échéances.";
    }
    return "L'échéance n'a pas pu être enregistrée.";
  }
}
