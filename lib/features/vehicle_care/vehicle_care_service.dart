import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_care_models.dart';

class VehicleCareException implements Exception {
  const VehicleCareException(this.message);

  final String message;
}

class VehicleCareService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<VehicleCareBundle> loadBundle(String vehicleId) async {
    try {
      final dashboardRaw = await _client.rpc(
        'get_vehicle_dashboard',
        params: {'p_vehicle_id': vehicleId},
      );

      if (dashboardRaw is! Map) {
        throw const VehicleCareException(
          "Le tableau de bord du véhicule n'a pas pu être chargé.",
        );
      }

      final schedulesRaw = await _client
          .from('vehicle_maintenance_schedules')
          .select(
            'id,title,schedule_type,due_date,due_mileage,interval_months,'
            'interval_km,status,priority,source_type,reason',
          )
          .eq('vehicle_id', vehicleId)
          .eq('status', 'ACTIVE')
          .order('due_date', ascending: true, nullsFirst: false)
          .order('due_mileage', ascending: true, nullsFirst: false);

      final suggestionsRaw = await _client
          .from('vehicle_document_suggestions')
          .select(
            'id,document_id,suggestion_type,title,payload,confidence,status,'
            'created_at',
          )
          .eq('vehicle_id', vehicleId)
          .eq('status', 'PENDING')
          .order('created_at', ascending: false);

      final documentsRaw = await _client
          .from('documents')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .eq('status', 'completed');

      return VehicleCareBundle(
        dashboard: VehicleCareDashboard.fromMap(
          Map<String, dynamic>.from(dashboardRaw),
        ),
        schedules: (schedulesRaw as List)
            .map(
              (row) => VehicleMaintenanceSchedule.fromMap(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(growable: false),
        suggestions: (suggestionsRaw as List)
            .map(
              (row) => VehicleDocumentSuggestion.fromMap(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(growable: false),
        completedDocumentCount: (documentsRaw as List).length,
      );
    } on VehicleCareException {
      rethrow;
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<int> applyDefaultMaintenancePlan(String vehicleId) async {
    try {
      final result = await _client.rpc(
        'apply_default_maintenance_plan',
        params: {'p_vehicle_id': vehicleId, 'p_replace_existing': false},
      );
      await _client.rpc(
        'recalculate_vehicle_reminders',
        params: {'p_vehicle_id': vehicleId},
      );
      return _integer(result);
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<void> recordEvent({
    required String vehicleId,
    required String eventType,
    required String title,
    required DateTime occurredAt,
    required String status,
    int? mileage,
    double? amount,
    String? providerName,
    String? description,
  }) async {
    try {
      await _client.rpc(
        'record_vehicle_event',
        params: {
          'p_vehicle_id': vehicleId,
          'p_event_type': eventType,
          'p_title': title.trim(),
          'p_occurred_at': occurredAt.toIso8601String(),
          'p_status': status,
          'p_mileage': status == 'COMPLETED' ? mileage : null,
          'p_amount': amount,
          'p_currency': 'EUR',
          'p_provider_name': _nullIfEmpty(providerName),
          'p_description': _nullIfEmpty(description),
          'p_location_text': null,
          'p_source_type': 'MANUAL',
          'p_source_document_id': null,
          'p_source_analysis_id': null,
          'p_confidence': null,
          'p_user_confirmed': true,
          'p_metadata': <String, dynamic>{
            if (status != 'COMPLETED' && mileage != null)
              'planned_mileage': mileage,
          },
          'p_create_expense':
              status == 'COMPLETED' && amount != null && amount > 0,
        },
      );
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<void> addOdometerReading({
    required String vehicleId,
    required int mileage,
    required DateTime readingAt,
  }) async {
    try {
      await _client.rpc(
        'add_odometer_reading',
        params: {
          'p_vehicle_id': vehicleId,
          'p_mileage': mileage,
          'p_reading_at': readingAt.toIso8601String(),
          'p_source_type': 'MANUAL',
          'p_source_document_id': null,
          'p_source_analysis_id': null,
          'p_photo_storage_path': null,
          'p_confidence': null,
          'p_user_confirmed': true,
        },
      );
      await _client.rpc(
        'recalculate_vehicle_reminders',
        params: {'p_vehicle_id': vehicleId},
      );
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<void> completeSchedule({
    required String scheduleId,
    required DateTime completedAt,
    int? mileage,
    double? amount,
    String? providerName,
    String? notes,
  }) async {
    try {
      await _client.rpc(
        'complete_maintenance_schedule',
        params: {
          'p_schedule_id': scheduleId,
          'p_completed_at': completedAt.toIso8601String(),
          'p_mileage': mileage,
          'p_amount': amount,
          'p_provider_name': _nullIfEmpty(providerName),
          'p_notes': _nullIfEmpty(notes),
        },
      );
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<int> extractDocumentSuggestions(String vehicleId) async {
    final accessToken = _requireAccessToken();

    try {
      final documents = await _client
          .from('documents')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(30);

      var createdCount = 0;
      for (final row in documents as List) {
        final documentId = (row as Map)['id']?.toString();
        if (documentId == null || documentId.isEmpty) continue;

        final response = await _client.functions.invoke(
          'extract-vehicle-timeline-suggestions',
          body: {
            'document_id': documentId,
            'vehicle_id': vehicleId,
            'refresh': false,
          },
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        final data = response.data;
        if (data is Map && data['success'] == true) {
          createdCount += _integer(
            data['inserted_count'] ??
                data['created_count'] ??
                data['suggestion_count'],
          );
        }
      }

      return createdCount;
    } on FunctionException catch (error) {
      throw VehicleCareException(_functionMessage(error));
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<void> confirmSuggestion({
    required String suggestionId,
    required String vehicleId,
  }) async {
    try {
      await _client.rpc(
        'confirm_document_suggestion',
        params: {
          'p_suggestion_id': suggestionId,
          'p_vehicle_id': vehicleId,
          'p_overrides': <String, dynamic>{},
        },
      );
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<void> dismissSuggestion(String suggestionId) async {
    try {
      await _client.rpc(
        'dismiss_document_suggestion',
        params: {'p_suggestion_id': suggestionId},
      );
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<void> updateRecallStatus({
    required String matchId,
    required String status,
  }) async {
    try {
      await _client
          .from('vehicle_recall_matches')
          .update({
            'status': status,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', matchId);
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  String _requireAccessToken() {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const VehicleCareException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    return token;
  }

  static int _integer(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullIfEmpty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _functionMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final message = details['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return switch (error.status) {
      401 => 'Votre session a expiré. Reconnectez-vous.',
      404 => "Le document ou son analyse n'est plus disponible.",
      _ => "Les informations du document n'ont pas pu être préparées.",
    };
  }

  static String _message(Object error) {
    final raw = switch (error) {
      PostgrestException() => error.message,
      VehicleCareException() => error.message,
      _ => error.toString(),
    };

    if (raw.contains('AUTH_REQUIRED') || raw.toLowerCase().contains('jwt')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('EVENT_TITLE_REQUIRED')) {
      return "Donnez un titre à l'événement.";
    }
    if (raw.contains('EVENT_MILEAGE_INVALID') ||
        raw.contains('ODOMETER_MILEAGE_INVALID')) {
      return 'Le kilométrage doit être positif.';
    }
    if (raw.contains('EVENT_AMOUNT_INVALID')) {
      return 'Le montant doit être positif.';
    }
    if (raw.contains('DOCUMENT_SUGGESTION_ALREADY_REVIEWED')) {
      return 'Cette suggestion a déjà été traitée.';
    }
    if (raw.contains('DOCUMENT_SUGGESTION_NOT_FOUND')) {
      return "Cette suggestion n'est plus disponible.";
    }
    if (raw.contains('MAINTENANCE_SCHEDULE_NOT_FOUND')) {
      return "Cette échéance d'entretien n'est plus disponible.";
    }
    if (raw.toLowerCase().contains('permission')) {
      return "Vous n'avez pas accès à ces informations.";
    }

    return 'Une erreur est survenue dans le carnet du véhicule.';
  }
}
