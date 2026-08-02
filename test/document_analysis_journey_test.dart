import 'package:autoclair_app/features/documents/document_analysis_journey.dart';
import 'package:autoclair_app/features/documents/document_analysis_result.dart';
import 'package:autoclair_app/features/documents/document_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'réutilise le document déjà envoyé lorsqu’une analyse est relancée',
    () async {
      var uploadCalls = 0;
      var analysisCalls = 0;

      final journey = DocumentAnalysisJourney(
        analyzeDocument: (documentId) async {
          analysisCalls += 1;
          if (analysisCalls == 1) {
            throw StateError('échec temporaire');
          }

          return DocumentAnalysisResult(
            id: 'analysis-1',
            documentId: documentId,
            summary: 'Résumé',
            overallConfidence: 0.9,
            resultJson: const {},
          );
        },
      );

      Future<UploadedDocument> upload() async {
        uploadCalls += 1;
        return const UploadedDocument(
          documentId: 'document-1',
          objectPath: 'user/document-1/file.pdf',
        );
      }

      await expectLater(
        journey.run(uploadDocument: upload),
        throwsA(isA<StateError>()),
      );

      final result = await journey.run(uploadDocument: upload);

      expect(result.documentId, 'document-1');
      expect(journey.documentId, 'document-1');
      expect(uploadCalls, 1);
      expect(analysisCalls, 2);
    },
  );
}
