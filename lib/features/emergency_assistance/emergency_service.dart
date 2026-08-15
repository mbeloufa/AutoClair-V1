import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'emergency_models.dart';
import 'emergency_safety_engine.dart';

class EmergencyAssistanceService {
  EmergencyAssistanceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const mediaBucket = 'emergency-media';

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('Une session utilisateur valide est nécessaire.');
    }
    return id;
  }

  Future<List<EmergencyVehicleOption>> fetchVehicles() async {
    final rows = await _client
        .from('vehicles')
        .select(
          'id,nickname,make,model,vehicle_year,fuel_type,mileage,registration_number,updated_at',
        )
        .eq('user_id', _userId)
        .order('is_primary', ascending: false)
        .order('updated_at', ascending: false);

    return (rows as List)
        .whereType<Map>()
        .map(
          (row) =>
              EmergencyVehicleOption.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<EmergencyAssistanceProfile> fetchAssistanceProfile(
    String vehicleId,
  ) async {
    final row = await _client
        .from('assistance_profiles')
        .select('provider_name,phone_number,contract_number,coverage_note')
        .eq('user_id', _userId)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    return EmergencyAssistanceProfile.fromMap(
      row == null ? null : Map<String, dynamic>.from(row),
    );
  }

  Future<void> saveAssistanceProfile({
    required String vehicleId,
    required String providerName,
    required String phoneNumber,
    required String contractNumber,
    required String coverageNote,
  }) async {
    final uid = _userId;
    await _client.from('assistance_profiles').upsert({
      'user_id': uid,
      'vehicle_id': vehicleId,
      'provider_name': providerName.trim(),
      'phone_number': phoneNumber.trim(),
      'contract_number': contractNumber.trim(),
      'coverage_note': coverageNote.trim(),
    }, onConflict: 'user_id,vehicle_id');
  }

  Future<String> createSession({
    required EmergencyVehicleOption vehicle,
    required EmergencyCategory category,
    required EmergencyRoadContext roadContext,
    required String description,
    required EmergencySafetyFlags flags,
    required double? latitude,
    required double? longitude,
    required double? locationAccuracyM,
  }) async {
    final row = await _client
        .from('emergency_sessions')
        .insert({
          'user_id': _userId,
          'vehicle_id': vehicle.id,
          'category': category.dbValue,
          'status': 'collecting',
          'user_stopped_safe': true,
          'road_context': roadContext.dbValue,
          'description': description.trim(),
          'symptom_flags': flags.toMap(),
          'latitude': latitude,
          'longitude': longitude,
          'location_accuracy_m': locationAccuracyM,
        })
        .select('id')
        .single();

    return row['id'].toString();
  }

  Future<void> updateSession({
    required String sessionId,
    required EmergencyCategory category,
    required EmergencyRoadContext roadContext,
    required String description,
    required EmergencySafetyFlags flags,
    required double? latitude,
    required double? longitude,
    required double? locationAccuracyM,
  }) async {
    await _client
        .from('emergency_sessions')
        .update({
          'category': category.dbValue,
          'road_context': roadContext.dbValue,
          'description': description.trim(),
          'symptom_flags': flags.toMap(),
          'latitude': latitude,
          'longitude': longitude,
          'location_accuracy_m': locationAccuracyM,
          'status': 'collecting',
        })
        .eq('id', sessionId)
        .eq('user_id', _userId);
  }

  Future<void> addClarification({
    required String sessionId,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final row = await _client
        .from('emergency_sessions')
        .select('clarifications')
        .eq('id', sessionId)
        .eq('user_id', _userId)
        .single();

    final current = (row['clarifications'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: true);

    current.add(clean);
    if (current.length > 12) {
      current.removeRange(0, current.length - 12);
    }

    await _client
        .from('emergency_sessions')
        .update({'clarifications': current, 'status': 'collecting'})
        .eq('id', sessionId)
        .eq('user_id', _userId);
  }

  Future<void> uploadMedia({
    required String sessionId,
    required EmergencyPendingMedia media,
  }) async {
    final uid = _userId;
    final bytes = Uint8List.fromList(media.bytes);
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw StateError('Le fichier doit faire moins de 10 Mo.');
    }

    final safeName = media.fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final objectPath = '$uid/$sessionId/${timestamp}_$safeName';

    await _client.storage
        .from(mediaBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: media.mimeType, upsert: false),
        );

    try {
      await _client.from('emergency_media').insert({
        'session_id': sessionId,
        'user_id': uid,
        'kind': media.kind,
        'object_path': objectPath,
        'original_name': media.fileName,
        'mime_type': media.mimeType,
        'size_bytes': bytes.length,
      });
    } catch (_) {
      await _client.storage.from(mediaBucket).remove([objectPath]);
      rethrow;
    }
  }

  Future<EmergencyAssessmentResult> analyzeSession(String sessionId) async {
    final response = await _client.functions.invoke(
      'analyze-emergency',
      body: {'session_id': sessionId},
    );

    if (response.data is! Map) {
      throw StateError('La réponse du service d’assistance est invalide.');
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['success'] != true || data['assessment'] is! Map) {
      throw StateError(
        data['message']?.toString() ?? 'L’analyse n’a pas pu être terminée.',
      );
    }

    return EmergencyAssessmentResult.fromMap(
      Map<String, dynamic>.from(data['assessment'] as Map),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final uid = _userId;
    final rows = await _client
        .from('emergency_media')
        .select('object_path')
        .eq('session_id', sessionId)
        .eq('user_id', uid);

    final paths = (rows as List)
        .whereType<Map>()
        .map((row) => row['object_path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    if (paths.isNotEmpty) {
      await _client.storage.from(mediaBucket).remove(paths);
    }

    await _client
        .from('emergency_sessions')
        .delete()
        .eq('id', sessionId)
        .eq('user_id', uid);
  }

  Future<String> saveIncident({
    required String sessionId,
    required EmergencyAssessmentResult result,
  }) async {
    final uid = _userId;
    final session = await _client
        .from('emergency_sessions')
        .select(
          'vehicle_id,category,description,road_context,latitude,longitude,symptom_flags,saved_event_id',
        )
        .eq('id', sessionId)
        .eq('user_id', uid)
        .single();

    final existingEventId = session['saved_event_id']?.toString();
    if (existingEventId != null && existingEventId.isNotEmpty) {
      return existingEventId;
    }

    final vehicleId = session['vehicle_id'].toString();
    final vehicle = await _client
        .from('vehicles')
        .select('mileage')
        .eq('id', vehicleId)
        .eq('user_id', uid)
        .single();

    final categoryValue = session['category']?.toString() ?? 'other';
    final category = EmergencyCategory.values.firstWhere(
      (value) => value.dbValue == categoryValue,
      orElse: () => EmergencyCategory.other,
    );

    final event = await _client
        .from('vehicle_events')
        .insert({
          'user_id': uid,
          'vehicle_id': vehicleId,
          'event_type': 'CONDITION',
          'status': 'COMPLETED',
          'title': 'Incident - ${category.label}',
          'description': result.summary.isNotEmpty
              ? result.summary
              : session['description']?.toString(),
          'occurred_at': DateTime.now().toUtc().toIso8601String(),
          'mileage': (vehicle['mileage'] as num?)?.round(),
          'source_type': 'USER_CONFIRMED',
          'user_confirmed': true,
          'metadata': {
            'emergency_session_id': sessionId,
            'safety_level': result.level.dbValue,
            'road_context': session['road_context'],
            'latitude': session['latitude'],
            'longitude': session['longitude'],
            'symptom_flags': session['symptom_flags'],
          },
        })
        .select('id')
        .single();

    final eventId = event['id'].toString();
    await _client
        .from('emergency_sessions')
        .update({'saved_event_id': eventId, 'status': 'closed'})
        .eq('id', sessionId)
        .eq('user_id', uid);

    return eventId;
  }
}
