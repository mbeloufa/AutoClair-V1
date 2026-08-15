import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_care_models.dart';

class MaintenanceV14Preference {
  const MaintenanceV14Preference({
    required this.key,
    required this.enabled,
    required this.leadDays,
    this.frequencyMonths,
    this.preferredMonth,
    this.lastCompletedAt,
    this.lastCompletedMileage,
  });

  final String key;
  final bool enabled;
  final List<int> leadDays;
  final int? frequencyMonths;
  final int? preferredMonth;
  final DateTime? lastCompletedAt;
  final int? lastCompletedMileage;

  factory MaintenanceV14Preference.fromMap(Map<String, dynamic> map) {
    final rawLeadDays = map['lead_days'];
    return MaintenanceV14Preference(
      key: map['reminder_key']?.toString() ?? '',
      enabled: map['enabled'] as bool? ?? true,
      leadDays: rawLeadDays is List
          ? rawLeadDays
                .map((value) => int.tryParse(value.toString()))
                .whereType<int>()
                .toList(growable: false)
          : const <int>[14, 0],
      frequencyMonths: _int(map['frequency_months']),
      preferredMonth: _int(map['preferred_month']),
      lastCompletedAt: _date(map['last_completed_at']),
      lastCompletedMileage: _int(map['last_completed_mileage']),
    );
  }
}

class MaintenanceV14State {
  const MaintenanceV14State({
    required this.masterEnabled,
    required this.annualMileageKm,
    required this.preferences,
    required this.events,
    this.firstRegistrationDate,
  });

  final bool masterEnabled;
  final int annualMileageKm;
  final Map<String, MaintenanceV14Preference> preferences;
  final List<VehicleTimelineEvent> events;
  final DateTime? firstRegistrationDate;
}

class MaintenanceV14Service {
  MaintenanceV14Service({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('SESSION_REQUIRED');
    }
    return id;
  }

  Future<MaintenanceV14State> load(String vehicleId) async {
    final profileRaw = await _client
        .from('vehicle_maintenance_planner_profiles')
        .select('annual_mileage_km,reminders_enabled')
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    final preferencesRaw = await _client
        .from('vehicle_maintenance_reminder_preferences')
        .select(
          'reminder_key,enabled,frequency_months,preferred_month,lead_days,'
          'last_completed_at,last_completed_mileage',
        )
        .eq('vehicle_id', vehicleId)
        .order('reminder_key');

    final eventsRaw = await _client
        .from('vehicle_events')
        .select(
          'id,event_type,status,title,description,occurred_at,mileage,amount,'
          'currency,provider_name,location_text,source_type,source_document_id,'
          'user_confirmed,metadata,reminder_enabled,reminder_days_before,'
          'reminder_at',
        )
        .eq('vehicle_id', vehicleId)
        .order('occurred_at', ascending: false)
        .limit(120);

    final vehicleRaw = await _client
        .from('vehicles')
        .select('first_registration_date')
        .eq('id', vehicleId)
        .maybeSingle();

    final preferences = <String, MaintenanceV14Preference>{};
    for (final raw in preferencesRaw as List) {
      final preference = MaintenanceV14Preference.fromMap(
        Map<String, dynamic>.from(raw as Map),
      );
      if (preference.key.isNotEmpty) {
        preferences[preference.key] = preference;
      }
    }

    final events = (eventsRaw as List)
        .map(
          (raw) => VehicleTimelineEvent.fromMap(
            Map<String, dynamic>.from(raw as Map),
          ),
        )
        .toList(growable: false);

    return MaintenanceV14State(
      masterEnabled: profileRaw?['reminders_enabled'] as bool? ?? false,
      annualMileageKm: _int(profileRaw?['annual_mileage_km']) ?? 12000,
      preferences: Map.unmodifiable(preferences),
      events: List.unmodifiable(events),
      firstRegistrationDate: _date(vehicleRaw?['first_registration_date']),
    );
  }

  Future<void> setMasterEnabled({
    required String vehicleId,
    required bool enabled,
  }) async {
    final userId = _userId;
    final current = await _client
        .from('vehicle_maintenance_planner_profiles')
        .select('id')
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    if (current == null) {
      await _client.from('vehicle_maintenance_planner_profiles').insert({
        'user_id': userId,
        'vehicle_id': vehicleId,
        'reminders_enabled': enabled,
      });
      return;
    }

    await _client
        .from('vehicle_maintenance_planner_profiles')
        .update({
          'reminders_enabled': enabled,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', current['id']);
  }

  Future<void> setPreference({
    required String vehicleId,
    required String key,
    required bool enabled,
    required List<int> leadDays,
    int? frequencyMonths,
    int? preferredMonth,
    DateTime? lastCompletedAt,
    int? lastCompletedMileage,
  }) async {
    final userId = _userId;
    final current = await _client
        .from('vehicle_maintenance_reminder_preferences')
        .select('id,last_completed_at,last_completed_mileage')
        .eq('vehicle_id', vehicleId)
        .eq('reminder_key', key)
        .maybeSingle();

    final payload = <String, dynamic>{
      'enabled': enabled,
      'lead_days': leadDays,
      'frequency_months': frequencyMonths,
      'preferred_month': preferredMonth,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (lastCompletedAt != null) {
      payload['last_completed_at'] = _dateOnly(lastCompletedAt);
    }
    if (lastCompletedMileage != null) {
      payload['last_completed_mileage'] = lastCompletedMileage;
    }

    if (current == null) {
      await _client.from('vehicle_maintenance_reminder_preferences').insert({
        'user_id': userId,
        'vehicle_id': vehicleId,
        'reminder_key': key,
        ...payload,
      });
      return;
    }

    await _client
        .from('vehicle_maintenance_reminder_preferences')
        .update(payload)
        .eq('id', current['id']);
  }

  Future<void> markManualDone({
    required String vehicleId,
    required String key,
    required String title,
    required String eventType,
    required bool enabled,
    required List<int> leadDays,
    int? frequencyMonths,
    int? preferredMonth,
    int? mileage,
  }) async {
    final userId = _userId;
    final now = DateTime.now();
    await _client.from('vehicle_events').insert({
      'user_id': userId,
      'vehicle_id': vehicleId,
      'event_type': eventType,
      'status': 'COMPLETED',
      'title': title,
      'occurred_at': now.toUtc().toIso8601String(),
      'completed_at': now.toUtc().toIso8601String(),
      'mileage': mileage,
      'source_type': 'USER_CONFIRMED',
      'user_confirmed': true,
      'metadata': <String, dynamic>{'maintenance_v14_key': key},
    });

    await setPreference(
      vehicleId: vehicleId,
      key: key,
      enabled: enabled,
      leadDays: leadDays,
      frequencyMonths: frequencyMonths,
      preferredMonth: preferredMonth,
      lastCompletedAt: now,
      lastCompletedMileage: mileage,
    );
  }
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toLocal();
}

String _dateOnly(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
