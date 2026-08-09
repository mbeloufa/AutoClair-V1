import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'V1 detects automotive contracts without adding new upload DB types',
    () {
      final catalog = _read(
        'lib/features/documents/document_type_catalog.dart',
      );
      final upload = _read('lib/features/documents/document_upload_page.dart');
      final function = _read('supabase/functions/analyze-document/index.ts');

      for (final type in [
        'purchase_order',
        'sale_contract',
        'lease_contract',
        'loa_contract',
        'lld_contract',
        'insurance_contract',
      ]) {
        expect(catalog, contains("value: '$type'"));
        expect(function, contains('"$type"'));
      }

      expect(catalog, contains('detectedOnlyDefinitions'));
      expect(upload, contains("String _documentType = 'other';"));
      expect(upload, contains('achat, vente, LOA/LLD et assurance'));
    },
  );

  test(
    'V1 contract analysis remains factual and outside the vehicle carnet',
    () {
      final function = _read('supabase/functions/analyze-document/index.ts');
      final model = _read(
        'lib/features/documents/document_analysis_result.dart',
      );
      final page = _read('lib/features/documents/analysis_result_page.dart');
      final card = _read(
        'lib/features/documents/contract_document_analysis_card.dart',
      );

      expect(function, contains('contract_analysis:'));
      expect(function, contains('commitment_summary'));
      expect(function, contains('important_clauses'));
      expect(function, contains('missing_information'));
      expect(function, contains('Ne juge jamais qu'));
      expect(function, contains("N'invente jamais un délai légal"));

      expect(model, contains('bool get isContractDocument'));
      expect(model, contains('bool get supportsCarnetSync'));
      expect(page, contains('ContractDocumentAnalysisCard'));
      expect(page, contains('if (result.supportsCarnetSync)'));
      expect(card, contains('ne remplace pas un conseil'));
      expect(card, contains('ne juge pas la validité d’une clause'));
    },
  );
}
