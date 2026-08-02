import 'package:file_picker/file_picker.dart';

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
  bool get isAvailable => false;

  Future<ScannedDocument?> scanDocument() {
    throw const DocumentScannerException(
      "Le scanner de documents n'est pas disponible "
      "sur cette plateforme.",
      code: 'SCANNER_UNAVAILABLE',
    );
  }
}
