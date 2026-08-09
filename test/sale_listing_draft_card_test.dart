import 'package:autoclair_app/features/sale_preparation/sale_listing_draft.dart';
import 'package:autoclair_app/features/sale_preparation/sale_listing_draft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sale listing draft stays readable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var copiedTitle = false;
    var copiedAll = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SaleListingDraftCard(
              draft: const SaleListingDraft(
                title: 'Renault Clio – 2019 – 84 000 km',
                description:
                    'Je vends mon Renault Clio de 2019. Kilométrage actuel : '
                    '84 000 km.',
                highlights: ['Factures disponibles'],
                informationToComplete: ['Équipements et options principales'],
                photoOrder: ['Vue trois-quarts avant'],
              ),
              onCopyTitle: () => copiedTitle = true,
              onCopyAll: () => copiedAll = true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Brouillon de votre annonce'), findsOneWidget);
    expect(find.text('À compléter avant publication'), findsOneWidget);

    await tester.ensureVisible(find.text('Copier le titre'));
    await tester.tap(find.text('Copier le titre'));
    await tester.pump();
    expect(copiedTitle, isTrue);

    await tester.ensureVisible(find.text('Copier l’annonce'));
    await tester.tap(find.text('Copier l’annonce'));
    await tester.pump();
    expect(copiedAll, isTrue);
    expect(tester.takeException(), isNull);
  });
}
