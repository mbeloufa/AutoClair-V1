import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autoclair_app/features/documents/contract_document_analysis_card.dart';
import 'package:autoclair_app/features/documents/document_analysis_result.dart';

void main() {
  testWidgets('contract card explains obligations costs and legal limit', (
    tester,
  ) async {
    final result = DocumentAnalysisResult.fromMap({
      'id': 'analysis-contract-card',
      'document_id': 'document-contract-card',
      'summary': 'Contrat LOA.',
      'overall_confidence': 0.9,
      'declared_document_type': 'other',
      'result_json': {
        'document_type_detected': 'loa_contract',
        'contract_analysis': {
          'commitment_summary': 'Location de 36 mois avec kilométrage prévu.',
          'obligations': [
            {
              'title': 'Kilométrage prévu',
              'explanation': 'Le document indique 45 000 km.',
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
              'explanation': 'Montant affiché dans le document.',
              'source': 'Échéancier',
              'confidence': 0.98,
            },
          ],
          'important_clauses': [
            {
              'title': 'Restitution',
              'explanation': 'Conditions à relire avant signature.',
              'source': 'Clause restitution',
              'confidence': 0.86,
            },
          ],
          'missing_information': ['Conditions de restitution peu lisibles'],
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContractDocumentAnalysisCard(result: result),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('contract-document-analysis-card')),
      findsOneWidget,
    );
    expect(find.text('Contrat LOA'), findsOneWidget);
    expect(find.text('Vos engagements à retenir'), findsOneWidget);
    expect(find.text('Kilométrage prévu'), findsOneWidget);
    expect(find.text('Coûts et paiements repérés'), findsOneWidget);
    expect(find.textContaining('329,00 EUR'), findsOneWidget);
    expect(find.text('Clauses à relire attentivement'), findsOneWidget);
    expect(find.text('Informations à vérifier'), findsOneWidget);
    expect(
      find.textContaining('ne remplace pas un conseil juridique'),
      findsOneWidget,
    );
  });
}
