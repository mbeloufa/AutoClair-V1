import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('V1 document entry defaults to automatic detection', () {
    final upload = _read('lib/features/documents/document_upload_page.dart');

    expect(upload, contains("String _documentType = 'other';"));
    expect(upload, contains('Type de document (facultatif)'));
    expect(upload, contains('Détection automatique'));

    // Dart format may split adjacent string literals over several lines.
    // Validate the semantic source contract without depending on one line.
    expect(
      RegExp(
        r"AutoClair reconnaît autant que '\s*'possible son type",
      ).hasMatch(upload),
      isTrue,
    );
  });

  test(
    'V1 technical inspection analysis is structured and privacy-minimal',
    () {
      final function = _read('supabase/functions/analyze-document/index.ts');
      final model = _read(
        'lib/features/documents/document_analysis_result.dart',
      );
      final page = _read('lib/features/documents/analysis_result_page.dart');
      final card = _read(
        'lib/features/documents/technical_inspection_analysis_card.dart',
      );

      expect(function, contains('autoclair-document-v2'));
      expect(function, contains('"technical_inspection_report"'));
      expect(function, contains('technical_inspection:'));
      expect(function, contains('reinspection_required'));
      expect(function, contains('recommended_action'));
      expect(function, isNot(contains('customer_name')));
      expect(function, isNot(contains('garage_address')));

      expect(model, contains('bool get isTechnicalInspection'));
      expect(model, contains('technicalInspectionDefects'));
      expect(page, contains('TechnicalInspectionAnalysisCard'));
      expect(card, contains('Contre-visite à prévoir'));
      expect(card, contains('défaillances relevées'));
    },
  );
}
