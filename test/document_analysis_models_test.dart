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

  test('retient l’opération automobile et masque le nom du client', () {
    final result = DocumentAnalysisResult.fromMap({
      'id': 'analysis-operation',
      'document_id': 'document-operation',
      'summary': 'Nom du client : Jean Dupont\nFiltre à huile remplacé',
      'overall_confidence': 0.94,
      'result_json': {
        'document_type_detected': 'invoice',
        'parties': {
          'client_name': 'Jean Dupont',
          'client_address': '1 rue Exemple',
          'customer_email': 'jean@example.fr',
          'garage_name': 'Garage Central',
          'garage_address': '10 avenue du Garage',
        },
        'recipient': {'owner_name': 'Jean Dupont', 'address': '1 rue Exemple'},
        'vehicle': {'mileage': 82450},
        'amounts': {'total_including_tax': 129.9, 'currency': 'EUR'},
        'line_items': [
          {'description': 'Main d’œuvre'},
          {'description': 'Filtre à huile'},
        ],
        'observations': [
          {
            'title': 'TVA et total TTC cohérents',
            'explanation': 'Vérification comptable',
          },
          {'title': 'Filtre remplacé', 'explanation': 'Entretien courant'},
        ],
        'questions_to_ask': [
          'Le total TTC est-il cohérent avec la TVA ?',
          'Quand prévoir la prochaine vidange ?',
        ],
      },
    });

    expect(result.summary, isNot(contains('Jean Dupont')));
    expect(result.resultJson.toString(), isNot(contains('Jean Dupont')));
    expect(result.resultJson.toString(), isNot(contains('owner_name')));
    expect(result.resultJson.toString(), isNot(contains('jean@example.fr')));
    expect(result.resultJson.toString(), isNot(contains('1 rue Exemple')));
    expect(result.resultJson.toString(), contains('Garage Central'));
    expect(result.resultJson.toString(), contains('10 avenue du Garage'));
    expect(result.detectedOperation.heading, 'Opération détectée');
    expect(result.detectedOperation.categoryLabel, 'Entretien');
    expect(result.detectedOperation.subcategoryLabel, 'Filtres et fluides');
    expect(result.detectedOperation.title, 'Filtre à huile');
    expect(result.detectedOperation.mileage, 82450);
    expect(result.detectedOperation.amount, 129.9);
    expect(result.usefulObservations.single['title'], 'Filtre remplacé');
    expect(result.usefulQuestions, ['Quand prévoir la prochaine vidange ?']);
  });

  test('utilise la détection IA lorsque le type déclaré est Autre', () {
    final result = DocumentAnalysisResult.fromMap({
      'id': 'analysis-auto',
      'document_id': 'document-auto',
      'summary': 'Facture détectée',
      'overall_confidence': 0.93,
      'declared_document_type': 'other',
      'result_json': {'document_type_detected': 'invoice'},
    });

    expect(result.effectiveDocumentType, 'invoice');
    expect(result.detectedTypeLabel, 'Facture');
  });

  test('structure les informations utiles du contrôle technique', () {
    final result = DocumentAnalysisResult.fromMap({
      'id': 'analysis-ct-structured',
      'document_id': 'document-ct',
      'summary': 'Contrôle technique avec contre-visite',
      'overall_confidence': 0.96,
      'declared_document_type': 'technical_inspection_report',
      'result_json': {
        'document_type_detected': 'technical_inspection_report',
        'technical_inspection': {
          'result': 'unfavorable_major',
          'reinspection_required': true,
          'reinspection_deadline': '2026-10-05',
          'defects': [
            {
              'severity': 'major',
              'code': '1.1.14.a.2',
              'wording': 'Disque ou tambour de frein usé',
              'explanation': 'Le freinage doit être contrôlé.',
              'recommended_action': 'Faire contrôler le freinage.',
              'confidence': 0.94,
            },
          ],
        },
      },
    });

    expect(result.isTechnicalInspection, isTrue);
    expect(
      result.technicalInspectionResultLabel,
      'Défavorable — défaillances majeures',
    );
    expect(result.technicalInspectionRequiresReinspection, isTrue);
    expect(result.technicalInspectionReinspectionDeadline, '2026-10-05');
    expect(result.technicalInspectionDefects.single['severity'], 'major');
  });

  test(
    'structure un contrat détecté sans le transformer en opération carnet',
    () {
      final result = DocumentAnalysisResult.fromMap({
        'id': 'analysis-contract',
        'document_id': 'doc-contract',
        'declared_document_type': 'other',
        'summary': 'Contrat de location automobile.',
        'overall_confidence': 0.91,
        'result_json': {
          'document_type_detected': 'loa_contract',
          'contract_analysis': {
            'commitment_summary': 'Location de 36 mois.',
            'obligations': [
              {
                'title': 'Kilométrage prévu',
                'explanation': 'Le contrat indique 45 000 km.',
                'source': 'Clause kilométrage',
                'confidence': 0.96,
              },
            ],
            'costs': [
              {
                'label': 'Loyer mensuel',
                'amount': 329.0,
                'currency': 'EUR',
                'frequency': 'mensuel',
                'explanation': 'Montant affiché dans le contrat.',
                'source': 'Échéancier',
                'confidence': 0.98,
              },
            ],
            'important_clauses': [
              {
                'title': 'Restitution',
                'explanation':
                    'Des frais peuvent être facturés selon le contrat.',
                'source': 'Clause restitution',
                'confidence': 0.86,
              },
            ],
            'missing_information': ['Conditions de restitution peu lisibles'],
          },
        },
      });

      expect(result.effectiveDocumentType, 'loa_contract');
      expect(result.detectedTypeLabel, 'Contrat LOA');
      expect(result.isContractDocument, isTrue);
      expect(result.supportsCarnetSync, isFalse);
      expect(result.contractCommitmentSummary, 'Location de 36 mois.');
      expect(result.contractObligations.single['title'], 'Kilométrage prévu');
      expect(result.contractCosts.single['amount'], 329.0);
      expect(result.contractImportantClauses.single['title'], 'Restitution');
      expect(result.contractMissingInformation, isNotEmpty);
    },
  );

  group('DocumentTypeCatalog', () {
    test(
      'garde cinq catégories sélectionnables et connaît les contrats détectés',
      () {
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
        expect(DocumentTypeCatalog.isSelectable('loa_contract'), isFalse);
        expect(DocumentTypeCatalog.isKnown('loa_contract'), isTrue);
        expect(
          DocumentTypeCatalog.labelFor('insurance_contract'),
          'Contrat d’assurance',
        );
      },
    );
  });
}
