import 'document_analysis_result.dart';
import 'document_upload_service.dart';

typedef DocumentUploadOperation = Future<UploadedDocument> Function();
typedef DocumentAnalysisOperation =
    Future<DocumentAnalysisResult> Function(String documentId);

class DocumentAnalysisJourney {
  DocumentAnalysisJourney({required DocumentAnalysisOperation analyzeDocument})
    : _analyzeDocument = analyzeDocument;

  final DocumentAnalysisOperation _analyzeDocument;

  UploadedDocument? _uploadedDocument;
  bool _running = false;

  bool get hasUploadedDocument => _uploadedDocument != null;
  String? get documentId => _uploadedDocument?.documentId;

  Future<DocumentAnalysisResult> run({
    required DocumentUploadOperation uploadDocument,
    void Function(String documentId)? onAnalysisStarted,
  }) async {
    if (_running) {
      throw StateError('Une analyse est déjà en cours.');
    }

    _running = true;

    try {
      final uploadedDocument = _uploadedDocument ??= await uploadDocument();

      onAnalysisStarted?.call(uploadedDocument.documentId);
      return await _analyzeDocument(uploadedDocument.documentId);
    } finally {
      _running = false;
    }
  }
}
