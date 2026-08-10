import 'package:autoclair_app/features/home/action_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('commercial V1 stays readable at 280 px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: ActionCenterPage()));

    expect(find.text('De quoi avez-vous besoin ?'), findsOneWidget);
    expect(find.text('Mon véhicule & carnet'), findsOneWidget);
    expect(find.text('Analyser un document'), findsOneWidget);
    expect(find.text('Services autour de moi'), findsOneWidget);
    expect(find.text('Acheter un véhicule'), findsOneWidget);
    expect(find.text('Vendre mon véhicule'), findsOneWidget);
    expect(find.text('Offres automobiles'), findsOneWidget);

    for (final excluded in [
      'Gérer une panne',
      'Gérer un accident',
      'Réagir à un vol',
      'Anticiper les risques',
      'Inspecter mon véhicule',
      'Préparer mon départ',
      'Gérer une immobilisation',
      'Préparer mon contrôle technique',
      'Préparer ma visite au garage',
      'Suivre mes pneus',
      'Suivre ma batterie',
      'Suivre mes niveaux',
      'Vérifier éclairage et visibilité',
      'Vérifier mon freinage',
      'Restituer ma LOA / LLD',
      'Vérifier ma conformité',
      'Réviser mon assurance',
      'Optimiser mon plein',
      'Optimiser ma recharge',
      'Améliorer ma conduite',
    ]) {
      expect(find.text(excluded), findsNothing);
    }

    expect(tester.takeException(), isNull);
  });
}
