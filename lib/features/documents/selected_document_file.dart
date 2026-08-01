import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class DocumentFileValidationException implements Exception {
  const DocumentFileValidationException(this.message);

  final String message;
}

class SelectedDocumentFile {
  const SelectedDocumentFile({
    required this.originalName,
    required this.extension,
    required this.mimeType,
    required this.bytes,
  });

  static const int maximumSizeBytes = 15 * 1024 * 1024;

  final String originalName;
  final String extension;
  final String mimeType;
  final Uint8List bytes;

  int get sizeBytes => bytes.lengthInBytes;

  bool get isImage => mimeType == 'image/jpeg' || mimeType == 'image/png';

  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes octets';
    }

    final kilobytes = sizeBytes / 1024;
    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} Ko';
    }

    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1)} Mo';
  }

  factory SelectedDocumentFile.fromPlatformFile(PlatformFile file) {
    final extension = normalizedExtension(
      file.extension ?? extensionFromName(file.name),
    );

    final mimeType = mimeTypeForExtension(extension);
    if (mimeType == null) {
      throw const DocumentFileValidationException(
        'Sélectionnez un fichier PDF, JPEG ou PNG.',
      );
    }

    if (file.size <= 0) {
      throw const DocumentFileValidationException(
        'Le fichier sélectionné est vide.',
      );
    }

    if (file.size > maximumSizeBytes) {
      throw const DocumentFileValidationException(
        'Le fichier dépasse la limite de 15 Mo.',
      );
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const DocumentFileValidationException(
        "Le contenu du fichier n'a pas pu être lu.",
      );
    }

    if (bytes.lengthInBytes > maximumSizeBytes) {
      throw const DocumentFileValidationException(
        'Le fichier dépasse la limite de 15 Mo.',
      );
    }

    return SelectedDocumentFile(
      originalName: file.name.trim(),
      extension: extension,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  static String extensionFromName(String fileName) {
    final separatorIndex = fileName.lastIndexOf('.');
    if (separatorIndex < 0 || separatorIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(separatorIndex + 1);
  }

  static String normalizedExtension(String extension) {
    final value = extension.trim().toLowerCase();
    return value == 'jpeg' ? 'jpg' : value;
  }

  static String? mimeTypeForExtension(String extension) {
    return switch (normalizedExtension(extension)) {
      'pdf' => 'application/pdf',
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }
}
