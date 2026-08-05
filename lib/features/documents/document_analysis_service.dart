import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_analysis_result.dart';
import 'document_carnet_sync_result.dart';
import 'document_history_item.dart';

class DocumentAnalysisException implements Exception {
  const DocumentAnalysisException(this.message);

  final String message;
}

class DocumentAnalysisService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<DocumentHistoryItem>> fetchDocuments() async {
    try {
      final data = await _client
          .from('documents')
          .select(
            'id,document_type,status,created_at,completed_at,'
            'error_code,comment',
          )
          .order('created_at', ascending: false);

      return (data as List)
          .map(
            (item) => DocumentHistoryItem.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw DocumentAnalysisException(_databaseMessage(error));
    } catch (_) {
      throw const DocumentAnalysisException(
        "L'historique n'a pas pu être chargé.",
      );
    }
  }

  Future<DocumentAnalysisResult> analyzeDocument(String documentId) async {
    final accessToken = _requireAccessToken();

    try {
      final response = await _client.functions.invoke(
        'analyze-document',
        body: {'document_id': documentId},
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      final data = response.data;
      if (data is! Map) {
        throw const DocumentAnalysisException(
          "Le serveur d'analyse a renvoyé une réponse invalide.",
        );
      }

      final payload = Map<String, dynamic>.from(data);

      if (payload['success'] != true) {
        throw DocumentAnalysisException(
          payload['message']?.toString() ?? "L'analyse du document a échoué.",
        );
      }

      final rawAnalysis = payload['analysis'];
      if (rawAnalysis is! Map) {
        throw const DocumentAnalysisException(
          "Le résultat de l'analyse est introuvable.",
        );
      }

      final analysisMap = Map<String, dynamic>.from(rawAnalysis);
      final declaredDocumentType = await _fetchDeclaredDocumentType(documentId);
      if (declaredDocumentType != null) {
        analysisMap['declared_document_type'] = declaredDocumentType;
      }

      final result = DocumentAnalysisResult.fromMap(analysisMap);

      // L'analyse reste prioritaire : un incident de synchronisation du carnet
      // ne doit jamais masquer un résultat déjà obtenu. L'appel est néanmoins
      // attendu afin que l'événement soit créé avant l'ouverture de la page.
      try {
        await syncDocumentToCarnet(documentId, prepareSuggestions: false);
      } catch (_) {
        // La page de résultat réessaiera de façon idempotente et affichera
        // l'état exact à l'utilisateur.
      }

      return result;
    } on FunctionException catch (error) {
      throw DocumentAnalysisException(
        _functionMessage(error, operation: 'analysis'),
      );
    } on DocumentAnalysisException {
      rethrow;
    } catch (error) {
      final normalized = error.toString().toLowerCase();

      if (normalized.contains('timeout') || normalized.contains('timed out')) {
        throw const DocumentAnalysisException(
          "L'analyse prend plus de temps que prévu. "
          "Actualisez l'historique dans quelques instants.",
        );
      }

      throw const DocumentAnalysisException(
        "Le service d'analyse est temporairement indisponible.",
      );
    }
  }

  Future<DocumentCarnetSyncResult> syncDocumentToCarnet(
    String documentId, {
    bool prepareSuggestions = true,
  }) async {
    try {
      final rawSync = await _client.rpc(
        'sync_document_carnet_event',
        params: {'p_document_id': documentId, 'p_force_review': false},
      );

      final sync = DocumentCarnetSyncResult.fromMap(
        _asMap(
          rawSync,
          invalidMessage:
              "Le serveur n'a pas renvoyé l'état de synchronisation du carnet.",
        ),
      );

      if (!prepareSuggestions || !sync.needsReview || sync.vehicleId == null) {
        return sync;
      }

      try {
        final count = await _prepareTimelineSuggestions(
          documentId: documentId,
          vehicleId: sync.vehicleId!,
        );

        return sync.copyWith(suggestionCount: count);
      } on DocumentAnalysisException {
        return sync.copyWith(
          suggestionPreparationFailed: true,
          message:
              '${sync.message} Les propositions détaillées pourront être '
              'préparées depuis le carnet du véhicule.',
        );
      }
    } on PostgrestException catch (error) {
      throw DocumentAnalysisException(_syncDatabaseMessage(error));
    } on DocumentAnalysisException {
      rethrow;
    } catch (_) {
      throw const DocumentAnalysisException(
        "Le rattachement automatique au carnet est temporairement indisponible.",
      );
    }
  }

  Future<DocumentCarnetSyncResult> confirmDocumentCarnetEvent(
    String documentId,
  ) async {
    try {
      final rawResult = await _client.rpc(
        'confirm_document_carnet_event',
        params: {'p_document_id': documentId},
      );

      return DocumentCarnetSyncResult.fromMap(
        _asMap(
          rawResult,
          invalidMessage: "Le serveur n'a pas confirmé l'événement du carnet.",
        ),
      );
    } on PostgrestException catch (error) {
      final raw = error.message;

      if (raw.contains('DOCUMENT_CARNET_CONFIRM_NOT_FOUND')) {
        throw const DocumentAnalysisException(
          "L'événement automatique n'existe plus.",
        );
      }
      if (raw.contains('DOCUMENT_CARNET_CONFIRM_NOT_ALLOWED')) {
        throw const DocumentAnalysisException(
          "Cet événement ne peut pas être confirmé automatiquement.",
        );
      }
      if (raw.contains('DOCUMENT_CARNET_CONFIRM_UPDATE_FAILED')) {
        throw const DocumentAnalysisException(
          "La confirmation n'a pas pu être enregistrée.",
        );
      }

      throw DocumentAnalysisException(_syncDatabaseMessage(error));
    } on DocumentAnalysisException {
      rethrow;
    } catch (_) {
      throw const DocumentAnalysisException(
        "La confirmation de l'événement est temporairement indisponible.",
      );
    }
  }

  Future<int> _prepareTimelineSuggestions({
    required String documentId,
    required String vehicleId,
  }) async {
    final accessToken = _requireAccessToken();

    try {
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
      if (data is! Map || data['success'] != true) {
        throw const DocumentAnalysisException(
          "Les propositions pour le carnet n'ont pas pu être préparées.",
        );
      }

      final pending = await _client
          .from('vehicle_document_suggestions')
          .select('id')
          .eq('document_id', documentId)
          .eq('vehicle_id', vehicleId)
          .eq('status', 'PENDING');

      final pendingCount = pending.length;
      if (pendingCount > 0) return pendingCount;

      return _integer(
        data['inserted_count'] ??
            data['created_count'] ??
            data['suggestion_count'],
      );
    } on FunctionException catch (error) {
      throw DocumentAnalysisException(
        _functionMessage(error, operation: 'timeline_suggestions'),
      );
    } on DocumentAnalysisException {
      rethrow;
    } catch (_) {
      throw const DocumentAnalysisException(
        "Les propositions pour le carnet sont temporairement indisponibles.",
      );
    }
  }

  Future<void> deleteDocument(String documentId) async {
    final accessToken = _requireAccessToken();

    try {
      final response = await _client.functions.invoke(
        'delete-document',
        body: {'document_id': documentId},
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      final data = response.data;
      if (data is! Map) {
        throw const DocumentAnalysisException(
          'Le serveur de suppression a renvoyé une réponse invalide.',
        );
      }

      final payload = Map<String, dynamic>.from(data);

      if (payload['success'] != true) {
        throw DocumentAnalysisException(
          payload['message']?.toString() ??
              "Le document n'a pas pu être supprimé.",
        );
      }
    } on FunctionException catch (error) {
      throw DocumentAnalysisException(
        _functionMessage(error, operation: 'deletion'),
      );
    } on DocumentAnalysisException {
      rethrow;
    } catch (_) {
      throw const DocumentAnalysisException(
        'La suppression est temporairement indisponible.',
      );
    }
  }

  Future<DocumentAnalysisResult> fetchAnalysis(String documentId) async {
    try {
      final data = await _client
          .from('document_analyses')
          .select('id,document_id,summary,overall_confidence,result_json')
          .eq('document_id', documentId)
          .maybeSingle();

      if (data == null) {
        throw const DocumentAnalysisException(
          "Le résultat de l'analyse n'est pas encore disponible.",
        );
      }

      final analysisMap = Map<String, dynamic>.from(data);
      final declaredDocumentType = await _fetchDeclaredDocumentType(documentId);
      if (declaredDocumentType != null) {
        analysisMap['declared_document_type'] = declaredDocumentType;
      }

      return DocumentAnalysisResult.fromMap(analysisMap);
    } on PostgrestException catch (error) {
      throw DocumentAnalysisException(_databaseMessage(error));
    } on DocumentAnalysisException {
      rethrow;
    } catch (_) {
      throw const DocumentAnalysisException(
        "Le résultat de l'analyse n'a pas pu être chargé.",
      );
    }
  }

  Future<String?> _fetchDeclaredDocumentType(String documentId) async {
    try {
      final data = await _client
          .from('documents')
          .select('document_type')
          .eq('id', documentId)
          .maybeSingle();

      final value = data?['document_type']?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      // Le résultat de l'analyse reste disponible même si le libellé déclaré
      // ne peut pas être relu ponctuellement.
      return null;
    }
  }

  static Map<String, dynamic> _asMap(
    dynamic value, {
    required String invalidMessage,
  }) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }

    throw DocumentAnalysisException(invalidMessage);
  }

  static int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _syncDatabaseMessage(PostgrestException error) {
    final raw = error.message;
    if (raw.contains('DOCUMENT_CARNET_AUTH_REQUIRED')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (raw.contains('DOCUMENT_CARNET_DOCUMENT_NOT_FOUND')) {
      return "Ce document n'existe plus ou ne vous appartient pas.";
    }
    if (raw.contains('DOCUMENT_CARNET_ANALYSIS_NOT_FOUND')) {
      return "L'analyse du document n'est pas encore disponible.";
    }
    if (raw.contains('DOCUMENT_CARNET_EVENT_CREATE_FAILED')) {
      return "L'événement n'a pas pu être ajouté au carnet.";
    }
    if (raw.toLowerCase().contains('sync_document_carnet_event')) {
      return 'Le module de synchronisation du carnet doit être installé.';
    }
    return "Le rattachement automatique au carnet n'a pas pu être effectué.";
  }

  String _requireAccessToken() {
    final accessToken = _client.auth.currentSession?.accessToken;

    if (accessToken == null || accessToken.isEmpty) {
      throw const DocumentAnalysisException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }

    return accessToken;
  }

  static String _functionMessage(
    FunctionException error, {
    required String operation,
  }) {
    final details = error.details;

    if (details is Map) {
      final payload = Map<String, dynamic>.from(details);
      final message = payload['message']?.toString().trim();

      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errorCode = payload['error_code']?.toString();
      return _errorCodeMessage(errorCode, operation: operation);
    }

    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }

    if (operation == 'timeline_suggestions') {
      return switch (error.status) {
        401 => 'Votre session a expiré. Reconnectez-vous.',
        404 => "Le document ou son analyse n'est plus disponible.",
        _ => "Les propositions pour le carnet n'ont pas pu être préparées.",
      };
    }

    if (operation == 'deletion') {
      return switch (error.status) {
        401 => 'Votre session a expiré. Reconnectez-vous.',
        404 => "Ce document n'existe plus.",
        409 => "Le document ne peut pas être supprimé pendant l'analyse.",
        _ => "Le document n'a pas pu être supprimé.",
      };
    }

    return switch (error.status) {
      401 => 'Votre session a expiré. Reconnectez-vous.',
      404 => "Ce document n'existe plus.",
      409 => 'Une analyse de ce document est déjà en cours.',
      429 => 'Le service est momentanément très sollicité.',
      504 => "L'analyse a dépassé le délai autorisé.",
      _ => "L'analyse du document a échoué.",
    };
  }

  static String _errorCodeMessage(
    String? errorCode, {
    required String operation,
  }) {
    if (operation == 'timeline_suggestions') {
      return switch (errorCode) {
        'DOCUMENT_NOT_FOUND' =>
          "Ce document n'existe pas ou ne vous appartient pas.",
        'ANALYSIS_NOT_FOUND' =>
          "L'analyse du document n'est pas encore disponible.",
        _ => "Les propositions pour le carnet n'ont pas pu être préparées.",
      };
    }

    if (operation == 'deletion') {
      return switch (errorCode) {
        'DOCUMENT_ANALYSIS_PROCESSING' =>
          "Le document ne peut pas être supprimé pendant l'analyse.",
        'DOCUMENT_NOT_FOUND' =>
          "Ce document n'existe pas ou ne vous appartient pas.",
        'DOCUMENT_STORAGE_DELETE_FAILED' =>
          "Le fichier privé n'a pas pu être supprimé.",
        'DOCUMENT_DATABASE_DELETE_FAILED' =>
          "Les données du document n'ont pas pu être supprimées.",
        'SERVER_CONFIGURATION_ERROR' =>
          'La configuration serveur doit être vérifiée.',
        _ => "Le document n'a pas pu être supprimé.",
      };
    }

    return switch (errorCode) {
      'ANALYSIS_ALREADY_PROCESSING' =>
        'Une analyse de ce document est déjà en cours.',
      'DOCUMENT_FILE_MISSING' => "Aucun fichier n'est associé à ce document.",
      'DOCUMENT_NOT_FOUND' =>
        "Ce document n'existe pas ou ne vous appartient pas.",
      'OPENAI_RATE_LIMIT' => 'Le service est momentanément très sollicité.',
      'OPENAI_TIMEOUT' => "L'analyse a dépassé le délai autorisé.",
      'OPENAI_BILLING_ERROR' =>
        "Le service d'analyse n'est pas disponible pour le moment.",
      'OPENAI_AUTH_ERROR' =>
        "La configuration du service d'analyse doit être vérifiée.",
      'SERVER_CONFIGURATION_ERROR' =>
        "La configuration serveur de l'analyse est incomplète.",
      _ => "L'analyse du document a échoué.",
    };
  }

  static String _databaseMessage(PostgrestException error) {
    final normalized = error.message.toLowerCase();

    if (normalized.contains('jwt') || normalized.contains('permission')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }

    return "Les données de l'analyse n'ont pas pu être chargées.";
  }
}
