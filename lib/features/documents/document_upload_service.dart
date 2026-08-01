import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'selected_document_file.dart';

class DocumentUploadException implements Exception {
  const DocumentUploadException(this.message);

  final String message;
}

class UploadedDocument {
  const UploadedDocument({required this.documentId, required this.objectPath});

  final String documentId;
  final String objectPath;
}

class DocumentUploadService {
  static const _bucketId = 'vehicle-documents';

  final Uuid _uuid = const Uuid();

  SupabaseClient get _client => Supabase.instance.client;

  Future<UploadedDocument> uploadDocument({
    required String vehicleId,
    required String documentType,
    required String? comment,
    required SelectedDocumentFile file,
    required void Function(String message) onProgress,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const DocumentUploadException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }

    String? documentId;
    String? objectPath;

    try {
      onProgress('Création du dossier sécurisé…');

      final draftData = await _client.rpc(
        'create_document_draft',
        params: {
          'p_vehicle_id': vehicleId,
          'p_document_type': documentType,
          'p_comment': _nullIfEmpty(comment),
        },
      );

      documentId = _extractFirstId(
        draftData,
        missingMessage: "Le serveur n'a pas renvoyé l'identifiant du document.",
      );

      final fileId = _uuid.v4();
      objectPath = '$userId/$documentId/$fileId.${file.extension}';

      onProgress('Envoi du fichier dans le stockage privé…');

      await _client.storage
          .from(_bucketId)
          .uploadBinary(
            objectPath,
            file.bytes,
            fileOptions: FileOptions(
              contentType: file.mimeType,
              upsert: false,
              cacheControl: '3600',
            ),
          );

      onProgress('Enregistrement des informations du fichier…');

      final registeredData = await _client.rpc(
        'register_document_file',
        params: {
          'p_document_id': documentId,
          'p_object_path': objectPath,
          'p_original_name': file.originalName,
          'p_mime_type': file.mimeType,
          'p_size_bytes': file.sizeBytes,
          'p_page_order': 1,
          'p_page_count': null,
        },
      );

      _extractFirstId(
        registeredData,
        missingMessage:
            "Le serveur n'a pas confirmé l'enregistrement du fichier.",
      );

      onProgress('Document enregistré de manière sécurisée.');

      return UploadedDocument(documentId: documentId, objectPath: objectPath);
    } catch (error) {
      await _cleanupFailedUpload(
        documentId: documentId,
        objectPath: objectPath,
      );

      if (error is DocumentUploadException) {
        rethrow;
      }

      throw DocumentUploadException(_message(error));
    }
  }

  Future<void> _cleanupFailedUpload({
    required String? documentId,
    required String? objectPath,
  }) async {
    if (objectPath != null) {
      try {
        await _client.storage.from(_bucketId).remove([objectPath]);
      } catch (_) {
        // Le nettoyage du brouillon continue même si l'objet n'existe plus.
      }
    }

    if (documentId != null) {
      try {
        await _client.rpc(
          'delete_document_draft',
          params: {'p_document_id': documentId},
        );
      } catch (_) {
        // Le brouillon pourra être nettoyé ultérieurement côté serveur.
      }
    }
  }

  static String _extractFirstId(
    dynamic data, {
    required String missingMessage,
  }) {
    if (data is List && data.isNotEmpty && data.first is Map) {
      final id = (data.first as Map)['id']?.toString();
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    if (data is Map) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    throw DocumentUploadException(missingMessage);
  }

  static String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _message(Object error) {
    final rawMessage = switch (error) {
      PostgrestException() => error.message,
      StorageException() => error.message,
      _ => error.toString(),
    };

    final normalized = rawMessage.toLowerCase();

    if (rawMessage.contains('DOCUMENT_VEHICLE_REQUIRED')) {
      return 'Sélectionnez le véhicule concerné.';
    }
    if (rawMessage.contains('DOCUMENT_TYPE_INVALID')) {
      return 'Sélectionnez un type de document valide.';
    }
    if (rawMessage.contains('DOCUMENT_COMMENT_TOO_LONG')) {
      return 'Le commentaire ne doit pas dépasser 2 000 caractères.';
    }
    if (rawMessage.contains('VEHICLE_NOT_FOUND')) {
      return "Ce véhicule n'existe plus ou ne vous appartient pas.";
    }
    if (rawMessage.contains('DOCUMENT_FILE_TYPE_INVALID') ||
        rawMessage.contains('DOCUMENT_FILE_EXTENSION_MISMATCH')) {
      return 'Le fichier doit être au format PDF, JPEG ou PNG.';
    }
    if (rawMessage.contains('DOCUMENT_FILE_SIZE_INVALID')) {
      return 'Le fichier doit peser moins de 15 Mo.';
    }
    if (rawMessage.contains('DOCUMENT_FILE_PATH_FORBIDDEN')) {
      return "Le chemin de stockage sécurisé n'est pas valide.";
    }
    if (rawMessage.contains('DOCUMENT_STORAGE_OBJECT_NOT_FOUND')) {
      return "Le fichier n'a pas été retrouvé dans le stockage privé.";
    }
    if (rawMessage.contains('DOCUMENT_DRAFT_NOT_FOUND')) {
      return "Le brouillon du document n'existe plus.";
    }
    if (rawMessage.contains('AUTH_REQUIRED') ||
        normalized.contains('jwt expired')) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (normalized.contains('maximum allowed size') ||
        normalized.contains('payload too large') ||
        normalized.contains('entity too large')) {
      return 'Le fichier dépasse la limite de 15 Mo.';
    }
    if (normalized.contains('mime type') || normalized.contains('mime-type')) {
      return 'Le type de fichier est refusé par le stockage.';
    }
    if (normalized.contains('duplicate') ||
        normalized.contains('already exists')) {
      return 'Ce fichier a déjà été envoyé.';
    }

    return "L'envoi du document a échoué. Vérifiez votre connexion "
        'et réessayez.';
  }
}
