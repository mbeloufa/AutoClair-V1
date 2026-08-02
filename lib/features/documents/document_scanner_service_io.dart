import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class ScannedDocument {
  const ScannedDocument({required this.file, required this.pageCount});

  final PlatformFile file;
  final int pageCount;
}

class DocumentScannerException implements Exception {
  const DocumentScannerException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class DocumentScannerService {
  static const _channel = MethodChannel('fr.autoclair/document_scanner');

  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  Future<ScannedDocument?> scanDocument() async {
    if (!isAvailable) {
      throw const DocumentScannerException(
        "Le scanner de documents n'est pas disponible "
        "sur cette plateforme.",
        code: 'SCANNER_UNAVAILABLE',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'scanDocument',
      );

      if (result == null) return null;

      final path = result['path'] as String?;
      final nativeName = result['name'] as String?;
      final pageCount = (result['pageCount'] as num?)?.toInt() ?? 1;

      if (path == null || path.trim().isEmpty) {
        throw const DocumentScannerException(
          "Le scanner n'a retourné aucun fichier.",
          code: 'SCAN_FILE_MISSING',
        );
      }

      final sourceFile = File(path);

      if (!await sourceFile.exists()) {
        throw const DocumentScannerException(
          'Le fichier numérisé est introuvable.',
          code: 'SCAN_FILE_MISSING',
        );
      }

      final bytes = await sourceFile.readAsBytes();

      if (bytes.isEmpty) {
        throw const DocumentScannerException(
          'Le fichier numérisé est vide.',
          code: 'SCAN_FILE_EMPTY',
        );
      }

      final name = nativeName == null || nativeName.trim().isEmpty
          ? 'autoclair_scan.pdf'
          : nativeName.trim();

      return ScannedDocument(
        file: PlatformFile(
          name: name,
          size: bytes.length,
          bytes: bytes,
          path: path,
        ),
        pageCount: pageCount,
      );
    } on PlatformException catch (error) {
      throw DocumentScannerException(
        _messageForPlatformError(error),
        code: error.code,
      );
    } on FileSystemException catch (error) {
      throw DocumentScannerException(
        error.message.isEmpty
            ? "Le fichier numérisé n'a pas pu être lu."
            : error.message,
        code: 'SCAN_FILE_READ_FAILED',
      );
    }
  }

  String _messageForPlatformError(PlatformException error) {
    switch (error.code) {
      case 'SCAN_IN_PROGRESS':
        return 'Un scan est déjà en cours.';
      case 'SCANNER_UNSUPPORTED':
        return "Le scanner n'est pas compatible "
            'avec ce téléphone.';
      case 'SCANNER_START_FAILED':
        if (Platform.isAndroid) {
          return 'Le scanner ne peut pas démarrer. '
              'Vérifiez la connexion Internet et la mise '
              'à jour de Google Play Services.';
        }
        return 'Le scanner ne peut pas démarrer. '
            "Vérifiez l'accès à l'appareil photo "
            'et réessayez.';
      case 'SCAN_TOO_MANY_PAGES':
        return 'Le document contient plus de 10 pages. '
            'Recommencez avec 10 pages maximum.';
      case 'SCAN_RESULT_FAILED':
        return "Le document n'a pas pu être numérisé.";
      case 'PDF_UNAVAILABLE':
        return "Le scanner n'a produit aucun fichier PDF.";
      case 'SCAN_FILE_FAILED':
        return "Le PDF numérisé n'a pas pu être préparé.";
      default:
        final message = error.message?.trim();
        return message == null || message.isEmpty
            ? "Le document n'a pas pu être numérisé."
            : message;
    }
  }
}
