import 'package:autoclair_app/features/used_purchase/used_listing_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts basic facts and cautious signals from a pasted listing', () {
    const listing = '''
Renault Clio 2020, 78 500 km, 13 900 €.
Entretien suivi avec factures. Rapport HistoVec disponible.
Voyant moteur allumé depuis peu. Acompte pour réserver avant visite.
''';

    final analysis = UsedListingAnalyzer.analyze(
      listing,
      now: DateTime(2026, 8, 9),
    );

    expect(analysis.detectedYear, 2020);
    expect(analysis.detectedMileage, 78500);
    expect(analysis.detectedPrice, 13900);
    expect(
      analysis.mentionedEvidence,
      contains('Entretien ou justificatifs mentionnés'),
    );
    expect(analysis.mentionedEvidence, contains('HistoVec mentionné'));
    expect(
      analysis.findings.map((item) => item.title),
      contains('Anomalie technique mentionnée'),
    );
    expect(
      analysis.findings.map((item) => item.title),
      contains('Paiement ou réservation à sécuriser'),
    );
    expect(analysis.questions.join(' '), contains('avant tout versement'));
  });

  test('lists missing essentials without inventing market or fraud claims', () {
    const listing = '''
Volkswagen Golf entretenue, carnet disponible.
Véhicule visible sur rendez-vous. Contrôle technique disponible.
''';

    final analysis = UsedListingAnalyzer.analyze(
      listing,
      now: DateTime(2026, 8, 9),
    );

    expect(analysis.detectedYear, isNull);
    expect(analysis.detectedMileage, isNull);
    expect(analysis.detectedPrice, isNull);
    expect(analysis.missingEssentials, ['année', 'kilométrage', 'prix']);

    final combined = [
      ...analysis.findings.map((item) => '${item.title} ${item.detail}'),
      ...analysis.questions,
    ].join(' ').toLowerCase();

    expect(combined, isNot(contains('arnaque certaine')));
    expect(combined, isNot(contains('prix du marché')));
    expect(combined, isNot(contains('bonne affaire')));
  });

  test(
    'treats urgent wording as a verification signal, not proof of fraud',
    () {
      const listing = '''
Peugeot 208 2019, 62 000 km, 10 500 euros.
Vente urgente, premier arrivé premier servi.
''';

      final analysis = UsedListingAnalyzer.analyze(
        listing,
        now: DateTime(2026, 8, 9),
      );

      final pressure = analysis.findings.singleWhere(
        (item) => item.title == 'Pression temporelle mentionnée',
      );

      expect(pressure.detail, contains('n’est pas une preuve d’arnaque'));
    },
  );
}
