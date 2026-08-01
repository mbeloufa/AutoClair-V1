import 'package:supabase_flutter/supabase_flutter.dart';

import 'document_analysis_result.dart';
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
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken;

    if (accessToken == null || accessToken.isEmpty) {
      throw const DocumentAnalysisException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }

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

      return DocumentAnalysisResult.fromMap(
        Map<String, dynamic>.from(rawAnalysis),
      );
    } on FunctionException catch (error) {
      throw DocumentAnalysisException(_functionMessage(error));
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

      return DocumentAnalysisResult.fromMap(Map<String, dynamic>.from(data));
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

  static String _functionMessage(FunctionException error) {
    final details = error.details;

    if (details is Map) {
      final payload = Map<String, dynamic>.from(details);
      final message = payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errorCode = payload['error_code']?.toString();
      return _errorCodeMessage(errorCode);
    }

    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
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

  static String _errorCodeMessage(String? errorCode) {
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
