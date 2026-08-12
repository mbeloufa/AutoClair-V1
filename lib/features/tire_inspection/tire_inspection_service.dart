import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'tire_inspection_models.dart';

class TireInspectionException implements Exception {
  const TireInspectionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TireInspectionService {
  TireInspectionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _bucket = 'tire-inspections';
  static const _function = 'analyze-tire-inspection';

  Future<String> createInspection(String vehicleId) async {
    try {
      final result = await _client.rpc(
        'create_tire_ai_inspection',
        params: {'p_vehicle_id': vehicleId},
      );
      final id = result?.toString().trim() ?? '';
      if (id.isEmpty) {
        throw const TireInspectionException(
          'Impossible de démarrer le contrôle pneus.',
        );
      }
      return id;
    } on TireInspectionException {
      rethrow;
    } catch (_) {
      throw const TireInspectionException(
        'Impossible de démarrer le contrôle pneus.',
      );
    }
  }

  Future<void> uploadPhoto({
    required String inspectionId,
    required String vehicleId,
    required TirePhotoSlot slot,
    required Uint8List bytes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const TireInspectionException('Session expirée. Reconnectez-vous.');
    }
    if (bytes.isEmpty) {
      throw const TireInspectionException('La photo est vide.');
    }
    final path = '$userId/$vehicleId/$inspectionId/${slot.apiValue}.jpg';
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      await _client.from('tire_ai_photos').upsert({
        'inspection_id': inspectionId,
        'user_id': userId,
        'vehicle_id': vehicleId,
        'slot': slot.apiValue,
        'storage_path': path,
        'content_type': 'image/jpeg',
      }, onConflict: 'inspection_id,slot');
    } catch (_) {
      throw const TireInspectionException(
        'Impossible d’envoyer cette photo. Réessayez.',
      );
    }
  }

  Future<Set<String>> fetchCapturedSlots(String inspectionId) async {
    try {
      final rows = await _client
          .from('tire_ai_photos')
          .select('slot')
          .eq('inspection_id', inspectionId);
      return (rows as List)
          .whereType<Map>()
          .map((row) => row['slot']?.toString() ?? '')
          .where((slot) => slot.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<TireInspectionResult> analyze(String inspectionId) async {
    try {
      final response = await _client.functions.invoke(
        _function,
        body: {'action': 'analyze', 'inspection_id': inspectionId},
      );
      if (response.status < 200 ||
          response.status >= 300 ||
          response.data is! Map) {
        throw const TireInspectionException(
          'L’analyse des pneus a échoué. Réessayez.',
        );
      }
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (payload['success'] != true || payload['analysis'] is! Map) {
        throw TireInspectionException(
          _messageForError(payload['error']?.toString()),
        );
      }
      return TireInspectionResult.fromJson(
        Map<String, dynamic>.from(payload['analysis'] as Map),
      );
    } on TireInspectionException {
      rethrow;
    } catch (_) {
      throw const TireInspectionException(
        'L’analyse des pneus a échoué. Réessayez.',
      );
    }
  }

  Future<List<TireRetailOffer>> fetchOffers(String inspectionId) async {
    try {
      final response = await _client.functions.invoke(
        _function,
        body: {'action': 'offers', 'inspection_id': inspectionId},
      );
      if (response.status < 200 ||
          response.status >= 300 ||
          response.data is! Map) {
        throw const TireInspectionException(
          'Impossible de rechercher les prix pour le moment.',
        );
      }
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (payload['success'] != true) {
        throw TireInspectionException(
          _messageForError(payload['error']?.toString()),
        );
      }
      final offers = payload['offers'];
      if (offers is! List) {
        return const [];
      }
      return offers
          .whereType<Map>()
          .map(
            (item) => TireRetailOffer.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (item) => item.url.startsWith('https://') && item.unitPriceEur > 0,
          )
          .toList(growable: false);
    } on TireInspectionException {
      rethrow;
    } catch (_) {
      throw const TireInspectionException(
        'Impossible de rechercher les prix pour le moment.',
      );
    }
  }

  String _messageForError(String? code) => switch (code) {
    'PHOTOS_INCOMPLETE' => 'Les 6 photos sont nécessaires avant l’analyse.',
    'ANALYSIS_NOT_READY' =>
      'Le diagnostic doit être terminé avant de comparer les prix.',
    'DIMENSION_UNCERTAIN' =>
      'La dimension du pneu n’est pas assez fiable pour proposer des prix.',
    'REPLACEMENT_NOT_RECOMMENDED' =>
      'Aucun remplacement n’est actuellement recommandé par l’analyse.',
    _ => 'Le service de contrôle pneus est temporairement indisponible.',
  };
}
