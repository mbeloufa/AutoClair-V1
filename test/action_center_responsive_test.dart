import 'package:autoclair_app/features/home/action_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('action center exposes every Lot 4 to Lot 11 tool at 280 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final routes = <String>[
      '/breakdown-assistant',
      '/accident-assistant',
      '/used-purchase',
      '/sale-preparation',
      '/maintenance-planner',
      '/eco-driving',
      '/budget',
      '/fuel-optimizer',
      '/charging-optimizer',
      '/quote-comparison',
      '/compliance',
      '/insurance-review',
    ];

    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) => const ActionCenterPage(),
        ),
        for (final path in routes)
          GoRoute(path: path, builder: (context, state) => const Scaffold()),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Tous les outils AutoClair'), findsOneWidget);
    expect(find.byKey(const ValueKey('action-center-intro')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final listView = find.byKey(const ValueKey('action-center-scroll'));
    expect(listView, findsOneWidget);

    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);

    for (final label in [
      'Gérer une panne',
      'Gérer un accident',
      'Sécuriser mon achat',
      'Préparer ma vente',
      'Planifier mon entretien',
      'Améliorer ma conduite',
      'Mon budget automobile',
      'Optimiser mon plein',
      'Optimiser ma recharge',
      'Comparer mes devis',
      'Vérifier ma conformité',
      'Réviser mon assurance',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        220,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('action center buttons open their direct routes', (tester) async {
    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) => const ActionCenterPage(),
        ),
        GoRoute(
          path: '/breakdown-assistant',
          builder: (context, state) =>
              const Scaffold(body: Text('Panne ouverte')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final breakdownButton = find.byKey(
      const ValueKey('action-tool-/breakdown-assistant'),
    );
    expect(breakdownButton, findsOneWidget);

    await tester.tap(breakdownButton);
    await tester.pumpAndSettle();

    expect(find.text('Panne ouverte'), findsOneWidget);
    expect(find.byType(ActionCenterPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
