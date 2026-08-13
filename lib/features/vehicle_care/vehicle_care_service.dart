import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_care_models.dart';
import 'vehicle_event_reminder.dart';

class VehicleCareException implements Exception {
  const VehicleCareException(this.message);

  final String message;
}

class VehicleMaintenanceRefreshResult {
  const VehicleMaintenanceRefreshResult({
    required this.success,
    required this.manufacturerReady,
    required this.seasonalReady,
    this.errorCode,
    this.retryable = false,
  });

  final bool success;
  final bool manufacturerReady;
  final bool seasonalReady;
  final String? errorCode;
  final bool retryable;

  String get userMessage {
    switch (errorCode) {
      case 'AUTH_REQUIRED':
        return 'Votre session a expiré. Reconnectez-vous puis relancez la recherche.';
      case 'VEHICLE_NOT_FOUND':
        return 'Ce véhicule n’a pas pu être retrouvé. Rechargez sa fiche puis réessayez.';
      case 'BACKEND_NOT_CONFIGURED':
      case 'AI_CONFIGURATION_ERROR':
        return 'La recherche constructeur est indisponible à cause d’un problème de configuration du service.';
      case 'AI_RESPONSE_INCOMPLETE':
        return 'La recherche constructeur n’a pas pu aller au bout. Réessayez dans quelques instants.';
      case 'AI_TEMPORARILY_UNAVAILABLE':
      case 'AI_REQUEST_FAILED':
        return 'Le service de recherche constructeur est momentanément indisponible. Réessayez dans quelques instants.';
      case 'FUNCTION_UNREACHABLE':
        return 'Impossible de joindre le service d’entretien. Vérifiez votre connexion puis réessayez.';
      case 'MAINTENANCE_SERVICE_ERROR':
      case 'INVALID_RESPONSE':
        return 'Le service d’entretien a rencontré une erreur. Réessayez dans quelques instants.';
      default:
        return 'Le plan n’a pas pu être actualisé. Réessayez dans quelques instants.';
    }
  }
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
            'interval_km,status,priority,source_type,reason,source_key,source_url,'
            'source_label,confidence,source_quality,calculation_basis',
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

      final dashboardMap = Map<String, dynamic>.from(dashboardRaw);
      await _mergeEventDetails(dashboardMap, vehicleId);

      final parsedSchedules = (schedulesRaw as List)
          .map(
            (row) => VehicleMaintenanceSchedule.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
      _suppressGenericScheduleReminders(dashboardMap, parsedSchedules);
      final effectiveSchedules = _effectiveMaintenanceSchedules(
        parsedSchedules,
      );

      return VehicleCareBundle(
        dashboard: VehicleCareDashboard.fromMap(dashboardMap),
        schedules: effectiveSchedules,
        suggestions: (suggestionsRaw as List)
            .map(
              (row) => VehicleDocumentSuggestion.fromMap(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .where((suggestion) => suggestion.isUsefulVehicleOperation)
            .toList(growable: false),
        completedDocumentCount: (documentsRaw as List).length,
      );
    } on VehicleCareException {
      rethrow;
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  List<VehicleMaintenanceSchedule> _effectiveMaintenanceSchedules(
    List<VehicleMaintenanceSchedule> schedules,
  ) {
    return schedules
        .where((schedule) => !schedule.isGenericPlan)
        .toList(growable: false);
  }

  void _suppressGenericScheduleReminders(
    Map<String, dynamic> dashboard,
    List<VehicleMaintenanceSchedule> schedules,
  ) {
    final genericTitles = schedules
        .where((schedule) => schedule.isGenericPlan)
        .map((schedule) => _maintenanceTitleKey(schedule.title))
        .where((title) => title.isNotEmpty)
        .toSet();
    if (genericTitles.isEmpty) return;
    final actions = dashboard['upcoming_actions'];
    if (actions is! List) return;
    dashboard['upcoming_actions'] = actions
        .where((raw) {
          if (raw is! Map) return true;
          final map = Map<String, dynamic>.from(raw);
          if ((map['source_type']?.toString().toUpperCase() ?? '') !=
              'SCHEDULE') {
            return true;
          }
          return !genericTitles.contains(
            _maintenanceTitleKey(map['title']?.toString() ?? ''),
          );
        })
        .toList(growable: false);
  }

  String _maintenanceTitleKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüÿ]+'), ' ')
      .trim();

  Future<VehicleMaintenanceRefreshResult> refreshManufacturerMaintenancePlan(
    String vehicleId, {
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'refresh-vehicle-maintenance-plan',
        body: <String, dynamic>{
          'vehicle_id': vehicleId,
          'force_refresh': forceRefresh,
        },
      );
      final data = response.data;
      if (data is! Map) {
        return const VehicleMaintenanceRefreshResult(
          success: false,
          manufacturerReady: false,
          seasonalReady: false,
          errorCode: 'INVALID_RESPONSE',
        );
      }
      final map = Map<String, dynamic>.from(data);
      final success = map['success'] == true;
      return VehicleMaintenanceRefreshResult(
        success: success,
        manufacturerReady: success && map['status'] == 'READY',
        seasonalReady: success && map['seasonal_schedule'] == true,
        errorCode: success ? null : map['error']?.toString(),
        retryable: map['retryable'] == true,
      );
    } catch (error) {
      return VehicleMaintenanceRefreshResult(
        success: false,
        manufacturerReady: false,
        seasonalReady: false,
        errorCode: _maintenanceFunctionErrorCode(error),
        retryable: true,
      );
    }
  }

  String _maintenanceFunctionErrorCode(Object error) {
    dynamic details;
    int? status;
    if (error is FunctionException) {
      details = error.details;
      status = error.status;
    } else {
      try {
        details = (error as dynamic).details;
        status = (error as dynamic).status as int?;
      } catch (_) {}
    }
    if (details is Map) {
      final code = details['error']?.toString().trim();
      if (code != null && code.isNotEmpty) return code;
    }
    if (details is String && details.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map) {
          final code = decoded['error']?.toString().trim();
          if (code != null && code.isNotEmpty) return code;
        }
      } catch (_) {}
    }
    if (status == 401) return 'AUTH_REQUIRED';
    if (status == 404) return 'VEHICLE_NOT_FOUND';
    if (status == 429 || status == 504) return 'AI_TEMPORARILY_UNAVAILABLE';
    if (status == 500 || status == 502 || status == 503 || status == 546) {
      return 'MAINTENANCE_SERVICE_ERROR';
    }
    return 'FUNCTION_UNREACHABLE';
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

  Future<VehicleEventSaveResult> recordEvent({
    required String vehicleId,
    required String eventType,
    required String categoryCode,
    required String subcategoryCode,
    required String title,
    required DateTime occurredAt,
    required String status,
    int? mileage,
    double? amount,
    String? providerName,
    String? locationText,
    String? description,
    String? sourceDocumentId,
    bool reminderEnabled = false,
    int? reminderDaysBefore,
  }) async {
    final clientReference =
        'manual-${DateTime.now().microsecondsSinceEpoch}-$vehicleId';
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
          'p_location_text': _nullIfEmpty(locationText),
          'p_source_type': 'MANUAL',
          'p_source_document_id': _nullIfEmpty(sourceDocumentId),
          'p_source_analysis_id': null,
          'p_confidence': null,
          'p_user_confirmed': true,
          'p_metadata': <String, dynamic>{
            'category_code': categoryCode,
            'subcategory_code': subcategoryCode,
            'client_reference': clientReference,
            'reminder_enabled': status == 'PLANNED' && reminderEnabled,
            if (status == 'PLANNED' && reminderEnabled)
              'reminder_days_before': reminderDaysBefore,
            if (status != 'COMPLETED' && mileage != null)
              'planned_mileage': mileage,
          },
          'p_create_expense':
              status == 'COMPLETED' && amount != null && amount > 0,
        },
      );

      String? eventId;
      try {
        final event = await _client
            .from('vehicle_events')
            .select('id')
            .eq('vehicle_id', vehicleId)
            .contains('metadata', <String, dynamic>{
              'client_reference': clientReference,
            })
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        eventId = event?['id']?.toString();
      } catch (_) {
        // L'événement est bien enregistré même si son identifiant ne peut pas
        // être relu immédiatement. Le clientReference reste stable pour le rappel.
      }

      return VehicleEventSaveResult(
        clientReference: clientReference,
        eventId: eventId,
      );
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<List<VehicleEventReminderPlan>> fetchPlannedEventReminders(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('vehicle_events')
          .select(
            'id,title,occurred_at,status,reminder_enabled,reminder_days_before',
          )
          .eq('vehicle_id', vehicleId)
          .eq('status', 'PLANNED')
          .eq('reminder_enabled', true)
          .order('occurred_at');

      return (rows as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .where((row) {
            final days = _integer(row['reminder_days_before']);
            return row['id'] != null &&
                row['occurred_at'] != null &&
                isSupportedVehicleEventReminderDays(days);
          })
          .map((row) {
            final days = _integer(row['reminder_days_before']);
            return VehicleEventReminderPlan(
              vehicleId: vehicleId,
              eventKey: row['id'].toString(),
              eventTitle: row['title']?.toString().trim().isNotEmpty == true
                  ? row['title'].toString().trim()
                  : 'Événement prévu',
              eventDate: DateTime.parse(
                row['occurred_at'].toString(),
              ).toLocal(),
              daysBefore: days,
            );
          })
          .toList(growable: false);
    } catch (error) {
      throw VehicleCareException(_message(error));
    }
  }

  Future<List<VehicleEventDocumentOption>> fetchLinkableDocuments(
    String vehicleId,
  ) async {
    try {
      final rows = await _client
          .from('documents')
          .select('id,document_type,status,created_at,vehicle_id,comment')
          .or('vehicle_id.eq.$vehicleId,vehicle_id.is.null')
          .order('created_at', ascending: false)
          .limit(60);

      final documents = (rows as List)
          .map(
            (row) => VehicleEventDocumentOption.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
      documents.sort((left, right) {
        final leftRank = left.vehicleId == vehicleId ? 0 : 1;
        final rightRank = right.vehicleId == vehicleId ? 0 : 1;
        if (leftRank != rightRank) return leftRank.compareTo(rightRank);
        return right.createdAt.compareTo(left.createdAt);
      });
      return documents;
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
    required String categoryCode,
    required String subcategoryCode,
    int? mileage,
    double? amount,
  }) async {
    try {
      await _client.rpc(
        'confirm_document_suggestion_v2',
        params: {
          'p_suggestion_id': suggestionId,
          'p_vehicle_id': vehicleId,
          'p_mileage': mileage,
          'p_amount': amount,
          'p_category_code': categoryCode,
          'p_subcategory_code': subcategoryCode,
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

  Future<void> _mergeEventDetails(
    Map<String, dynamic> dashboard,
    String vehicleId,
  ) async {
    final rawEvents = dashboard['recent_events'];
    if (rawEvents is! List || rawEvents.isEmpty) return;

    try {
      final rows = await _client
          .from('vehicle_events')
          .select(
            'id,location_text,source_document_id,reminder_enabled,'
            'reminder_days_before,reminder_at',
          )
          .eq('vehicle_id', vehicleId)
          .order('occurred_at', ascending: false)
          .limit(80);

      final detailsById = <String, Map<String, dynamic>>{
        for (final row in rows as List)
          if ((row as Map)['id'] != null)
            row['id'].toString(): Map<String, dynamic>.from(row),
      };

      dashboard['recent_events'] = rawEvents
          .map((rawEvent) {
            if (rawEvent is! Map) return rawEvent;
            final event = Map<String, dynamic>.from(rawEvent);
            final details = detailsById[event['id']?.toString()];
            if (details != null) event.addAll(details);
            return event;
          })
          .toList(growable: false);
    } catch (_) {
      // Les champs enrichis restent facultatifs. Le tableau de bord principal
      // ne doit pas échouer si une ancienne base ne les expose pas encore.
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
    if (raw.contains('EVENT_VEHICLE_FORBIDDEN')) {
      return "Vous n’êtes pas autorisé à modifier ce véhicule.";
    }
    if (raw.contains('EVENT_DOCUMENT_NOT_ALLOWED')) {
      return "Ce document ne peut pas être lié à ce véhicule.";
    }
    if (raw.contains('EVENT_REMINDER_INVALID')) {
      return 'Le délai de rappel est invalide.';
    }
    if (raw.contains('DOCUMENT_SUGGESTION_ALREADY_REVIEWED')) {
      return 'Cette suggestion a déjà été traitée.';
    }
    if (raw.contains('DOCUMENT_OPERATION_V2_NOT_INSTALLED')) {
      return 'La mise à jour simplifiée du carnet doit être installée.';
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
