import 'dart:io';

import 'package:autoclair_app/features/documents/document_analysis_result.dart';
import 'package:autoclair_app/features/documents/service_document_analysis_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workshop document card explains what the document claims', (
    tester,
  ) async {
    final result = _result(
      type: 'estimate',
      dates: {'validity_end_date': '2026-08-31'},
      amounts: {'currency': 'EUR', 'total_including_tax': 514.8},
      items: [
        {
          'description': 'Disques et plaquettes avant',
          'total_excluding_tax': 370.5,
          'necessity_assessment': 'explicitly_required',
          'explanation': 'Le devis présente cette opération comme nécessaire.',
        },
        {
          'description': 'Liquide de frein',
          'total_excluding_tax': 42.0,
          'necessity_assessment': 'recommended',
          'explanation': 'Le remplacement est recommandé sur le document.',
        },
        {
          'description': 'Nettoyant frein',
          'total_excluding_tax': 8.0,
          'necessity_assessment': 'optional',
          'explanation': 'Cette ligne est présentée comme optionnelle.',
        },
        {
          'description': 'Contrôle complémentaire',
          'necessity_assessment': 'unclear',
          'explanation': 'Le motif n’est pas suffisamment explicite.',
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceDocumentAnalysisCard(result: result),
          ),
        ),
      ),
    );

    expect(find.text('Ce que le garage vous propose'), findsOneWidget);
    expect(find.text('Total TTC 514,80 €'), findsOneWidget);
    expect(find.text('Valable jusqu’au 2026-08-31'), findsOneWidget);
    expect(find.text('1 point à clarifier'), findsOneWidget);
    expect(find.text('Présenté comme nécessaire'), findsOneWidget);
    expect(find.text('Recommandé sur le document'), findsOneWidget);
    expect(find.text('Optionnel sur le document'), findsOneWidget);
    expect(find.text('À clarifier'), findsOneWidget);
    expect(
      find.textContaining('ne confirme ni la nécessité technique'),
      findsOneWidget,
    );
    expect(find.text('Prioritaire'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'workshop document support stays limited to existing document types',
    () {
      expect(
        ServiceDocumentAnalysisCard.supports(_result(type: 'estimate')),
        isTrue,
      );
      expect(
        ServiceDocumentAnalysisCard.supports(_result(type: 'invoice')),
        isTrue,
      );
      expect(
        ServiceDocumentAnalysisCard.supports(_result(type: 'repair_order')),
        isTrue,
      );
      expect(
        ServiceDocumentAnalysisCard.supports(
          _result(type: 'technical_inspection_report'),
        ),
        isFalse,
      );
      expect(
        ServiceDocumentAnalysisCard.supports(_result(type: 'other')),
        isFalse,
      );
    },
  );

  test('Lot 3 improves presentation only and keeps analyze-document V2', () {
    final page = File(
      'lib/features/documents/analysis_result_page.dart',
    ).readAsStringSync();
    final backend = File(
      'supabase/functions/analyze-document/index.ts',
    ).readAsStringSync();

    expect(page, contains("import 'service_document_analysis_card.dart';"));
    expect(page, contains('ServiceDocumentAnalysisCard.supports(result)'));
    expect(page, contains('ServiceDocumentAnalysisCard(result: result)'));
    expect(backend, contains('autoclair-document-v2'));
    expect(backend, isNot(contains('autoclair-document-v3')));
  });
}

DocumentAnalysisResult _result({
  required String type,
  Map<String, dynamic> dates = const {},
  Map<String, dynamic> amounts = const {},
  List<Map<String, dynamic>> items = const [],
}) {
  return DocumentAnalysisResult.fromMap({
    'id': 'analysis-service',
    'document_id': 'document-service',
    'summary': 'Document atelier',
    'overall_confidence': 0.9,
    'declared_document_type': type,
    'result_json': {
      'document_type_detected': type,
      'dates': dates,
      'amounts': amounts,
      'line_items': items,
    },
  });
}
