import 'package:autoclair_app/features/quote_comparison/quote_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes equivalent automotive operations', () {
    expect(
      QuoteNormalizer.categoryFor('Forfait vidange huile moteur'),
      'Vidange moteur',
    );
    expect(
      QuoteNormalizer.categoryFor('Remplacement plaquettes AV'),
      'Freinage',
    );
    expect(
      QuoteNormalizer.categoryFor('Kit courroie de distribution'),
      'Distribution',
    );
    expect(
      QuoteNormalizer.categoryFor('Lecture codes défaut à la valise'),
      'Diagnostic',
    );
  });

  test('quote comparison computes total gap', () {
    final result = QuoteComparisonResult.fromQuotes([
      QuoteSnapshot(
        documentId: 'a',
        label: 'A',
        providerName: 'Garage A',
        documentDate: null,
        total: 600,
        lines: const [],
        confidence: 0.9,
      ),
      QuoteSnapshot(
        documentId: 'b',
        label: 'B',
        providerName: 'Garage B',
        documentDate: null,
        total: 510,
        lines: const [],
        confidence: 0.9,
      ),
    ]);
    expect(result.totalGap, 90);
  });
}
