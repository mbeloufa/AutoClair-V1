import 'package:autoclair_app/features/financial_tools/financial_tools_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('financial tools hub stays readable at 280 pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/savings',
      routes: [
        GoRoute(
          path: '/savings',
          builder: (context, state) => const FinancialToolsPage(),
        ),
        for (final path in [
          '/budget',
          '/fuel-optimizer',
          '/charging-optimizer',
          '/eco-driving',
          '/maintenance-planner',
          '/risk-forecast',
          '/vehicle-inspection',
          '/trip-readiness',
          '/vehicle-storage',
          '/technical-control-readiness',
          '/workshop-visit',
          '/tire-care',
          '/battery-care',
          '/fluid-care',
          '/visibility-care',
          '/breakdown-assistant',
          '/sale-preparation',
          '/used-purchase',
          '/accident-assistant',
          '/theft-assistant',
          '/compliance',
          '/quote-comparison',
          '/insurance-review',
        ])
          GoRoute(path: path, builder: (context, state) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsOneWidget);
    expect(find.text('Mes économies'), findsOneWidget);
    expect(find.text('Mon budget automobile'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final label in [
      'Optimiser mon plein',
      'Optimiser ma recharge',
      'Améliorer ma conduite',
      'Planifier mon entretien',
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
      'Gérer une panne',
      'Préparer ma vente',
      'Sécuriser mon achat',
      'Gérer un accident',
      'Réagir à un vol',
      'Réviser mon assurance',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
