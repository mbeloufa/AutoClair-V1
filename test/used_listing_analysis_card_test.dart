import 'package:autoclair_app/features/used_purchase/used_listing_analysis.dart';
import 'package:autoclair_app/features/used_purchase/used_listing_analysis_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('listing card shows facts, cautions and verification limits', (
    tester,
  ) async {
    const analysis = UsedListingAnalysis(
      detectedYear: 2020,
      detectedMileage: 78500,
      detectedPrice: 13900,
      mentionedEvidence: ['HistoVec mentionné'],
      findings: [
        UsedListingFinding(
          title: 'Anomalie technique mentionnée',
          detail: 'Un voyant est évoqué.',
        ),
      ],
      questions: ['Pouvez-vous transmettre le diagnostic ?'],
      missingEssentials: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UsedListingAnalysisCard(
              analysis: analysis,
              onCopyQuestions: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Première lecture de l’annonce'), findsOneWidget);
    expect(find.text('78 500 km'), findsOneWidget);
    expect(find.text('13 900 €'), findsOneWidget);
    expect(find.text('Anomalie technique mentionnée'), findsOneWidget);
    expect(find.text('HistoVec mentionné'), findsOneWidget);
    expect(find.text('Questions à poser au vendeur'), findsOneWidget);
    expect(find.textContaining('ne vérifie'), findsOneWidget);
    expect(find.textContaining('valeur de marché'), findsOneWidget);
  });
}

void _noop() {}
