import 'package:autoclair_app/features/documents/document_analysis_result.dart';
import 'package:autoclair_app/features/documents/technical_inspection_analysis_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('technical inspection card explains result and reinspection', (
    tester,
  ) async {
    final result = DocumentAnalysisResult.fromMap({
      'id': 'analysis-ct',
      'document_id': 'document-ct',
      'summary': 'Contrôle technique',
      'overall_confidence': 0.95,
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TechnicalInspectionAnalysisCard(result: result)),
      ),
    );

    expect(find.text('Contrôle technique'), findsOneWidget);
    expect(find.text('Défavorable — défaillances majeures'), findsOneWidget);
    expect(find.text('Contre-visite à prévoir'), findsOneWidget);
    expect(find.text('Avant le 2026-10-05'), findsOneWidget);
    expect(find.text('Majeure'), findsOneWidget);
    expect(find.text('Disque ou tambour de frein usé'), findsOneWidget);
  });
}
