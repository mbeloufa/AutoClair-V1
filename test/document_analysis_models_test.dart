import 'package:autoclair_app/features/documents/document_analysis_result.dart';
import 'package:autoclair_app/features/documents/document_history_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentHistoryItem', () {
    test('traduit les types et statuts', () {
      final item = DocumentHistoryItem.fromMap({
        'id': 'document-1',
        'document_type': 'estimate',
        'status': 'draft',
        'created_at': '2026-08-01T12:00:00Z',
      });

      expect(item.typeLabel, 'Devis');
      expect(item.statusLabel, 'Prêt à analyser');
      expect(item.canStartAnalysis, isTrue);
      expect(item.canDelete, isTrue);
    });

    test('reconnaît une analyse terminée', () {
      final item = DocumentHistoryItem.fromMap({
        'id': 'document-1',
        'document_type': 'invoice',
        'status': 'completed',
        'created_at': '2026-08-01T12:00:00Z',
      });

      expect(item.isCompleted, isTrue);
      expect(item.canStartAnalysis, isFalse);
      expect(item.canDelete, isTrue);
    });

    test('interdit la suppression pendant une analyse', () {
      final item = DocumentHistoryItem.fromMap({
        'id': 'document-1',
        'document_type': 'estimate',
        'status': 'processing',
        'created_at': '2026-08-01T12:00:00Z',
      });

      expect(item.isProcessing, isTrue);
      expect(item.canDelete, isFalse);
    });
  });

  group('DocumentAnalysisResult', () {
    test('lit les informations principales', () {
      final result = DocumentAnalysisResult.fromMap({
        'id': 'analysis-1',
        'document_id': 'document-1',
        'summary': 'Résumé',
        'overall_confidence': 0.82,
        'result_json': {
          'document_type_detected': 'estimate',
          'document_quality': {'readability': 'good'},
          'questions_to_ask': ['Question 1'],
        },
      });

      expect(result.detectedTypeLabel, 'Devis');
      expect(result.readabilityLabel, 'Bonne');
      expect(result.confidenceLabel, '82 %');
      expect(result.stringListAt('questions_to_ask'), ['Question 1']);
    });
  });
}
