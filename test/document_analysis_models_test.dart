import 'package:autoclair_app/features/documents/document_analysis_result.dart';
import 'package:autoclair_app/features/documents/document_history_item.dart';
import 'package:autoclair_app/features/documents/document_type_catalog.dart';
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

    test('traduit les nouvelles catégories', () {
      final inspection = DocumentHistoryItem.fromMap({
        'id': 'document-ct',
        'document_type': 'technical_inspection_report',
        'status': 'completed',
        'created_at': '2026-08-01T12:00:00Z',
      });
      final other = DocumentHistoryItem.fromMap({
        'id': 'document-other',
        'document_type': 'other',
        'status': 'draft',
        'created_at': '2026-08-01T12:00:00Z',
      });

      expect(inspection.typeLabel, 'Contrôle technique');
      expect(other.typeLabel, 'Autre');
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

    test('reconnaît un contrôle technique détecté', () {
      final result = DocumentAnalysisResult.fromMap({
        'id': 'analysis-ct',
        'document_id': 'document-ct',
        'summary': 'Contrôle technique',
        'overall_confidence': 0.91,
        'result_json': {
          'document_type_detected': 'technical_inspection_report',
        },
      });

      expect(result.detectedTypeLabel, 'Contrôle technique');
    });

    test(
      'conserve le contrôle technique déclaré face au modèle historique',
      () {
        final result = DocumentAnalysisResult.fromMap({
          'id': 'analysis-ct-declared',
          'document_id': 'document-ct',
          'summary': 'Procès-verbal de contrôle technique',
          'overall_confidence': 0.88,
          'declared_document_type': 'technical_inspection_report',
          'result_json': {'document_type_detected': 'repair_order'},
        });

        expect(result.detectedTypeLabel, 'Contrôle technique');
      },
    );

    test('utilise la catégorie déclarée lorsque le type reste indéterminé', () {
      final result = DocumentAnalysisResult.fromMap({
        'id': 'analysis-other',
        'document_id': 'document-other',
        'summary': 'Document libre',
        'overall_confidence': 0.55,
        'declared_document_type': 'other',
        'result_json': {'document_type_detected': 'unknown'},
      });

      expect(result.detectedTypeLabel, 'Autre');
    });
  });

  group('DocumentTypeCatalog', () {
    test('propose les cinq catégories utilisateur', () {
      expect(
        DocumentTypeCatalog.definitions.map((item) => item.value),
        containsAll([
          'estimate',
          'invoice',
          'repair_order',
          'technical_inspection_report',
          'other',
        ]),
      );
    });
  });
}
