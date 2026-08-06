import 'package:autoclair_app/features/home/action_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('action center exposes every Lot 4 to Lot 17 tool at 280 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final routes = <String>[
      '/breakdown-assistant',
      '/accident-assistant',
      '/theft-assistant',
      '/used-purchase',
      '/sale-preparation',
      '/maintenance-planner',
      '/risk-forecast',
      '/vehicle-inspection',
      '/trip-readiness',
      '/vehicle-storage',
      '/technical-control-readiness',
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
    addTearDown(router.dispose);

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
      'Réagir à un vol',
      'Sécuriser mon achat',
      'Préparer ma vente',
      'Planifier mon entretien',
      'Anticiper les risques',
      'Inspecter mon véhicule',
      'Préparer mon départ',
      'Gérer une immobilisation',
      'Préparer mon contrôle technique',
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

  testWidgets('risk forecast action opens its direct route', (tester) async {
    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) => const ActionCenterPage(),
        ),
        GoRoute(
          path: '/risk-forecast',
          builder: (context, state) =>
              const Scaffold(body: Text('Analyse des risques ouverte')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final listView = find.byKey(const ValueKey('action-center-scroll'));
    expect(listView, findsOneWidget);

    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);

    final riskButton = find.byKey(const ValueKey('action-tool-/risk-forecast'));
    await tester.scrollUntilVisible(riskButton, 220, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(riskButton, findsOneWidget);

    await tester.tap(riskButton);
    await tester.pumpAndSettle();

    expect(find.text('Analyse des risques ouverte'), findsOneWidget);
    expect(find.byType(ActionCenterPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle inspection action opens its direct route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) => const ActionCenterPage(),
        ),
        GoRoute(
          path: '/vehicle-inspection',
          builder: (context, state) =>
              const Scaffold(body: Text('Inspection ouverte')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final listView = find.byKey(const ValueKey('action-center-scroll'));
    expect(listView, findsOneWidget);
    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);

    final inspectionButton = find.byKey(
      const ValueKey('action-tool-/vehicle-inspection'),
    );
    await tester.scrollUntilVisible(
      inspectionButton,
      220,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(inspectionButton, findsOneWidget);

    await tester.tap(inspectionButton);
    await tester.pumpAndSettle();

    expect(find.text('Inspection ouverte'), findsOneWidget);
    expect(find.byType(ActionCenterPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trip readiness action opens its direct route', (tester) async {
    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) => const ActionCenterPage(),
        ),
        GoRoute(
          path: '/trip-readiness',
          builder: (context, state) =>
              const Scaffold(body: Text('Préparation du départ ouverte')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final listView = find.byKey(const ValueKey('action-center-scroll'));
    expect(listView, findsOneWidget);
    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);

    final tripButton = find.byKey(
      const ValueKey('action-tool-/trip-readiness'),
    );
    await tester.scrollUntilVisible(tripButton, 220, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(tripButton, findsOneWidget);

    await tester.tap(tripButton);
    await tester.pumpAndSettle();

    expect(find.text('Préparation du départ ouverte'), findsOneWidget);
    expect(find.byType(ActionCenterPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle storage action opens its direct route', (tester) async {
    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) => const ActionCenterPage(),
        ),
        GoRoute(
          path: '/vehicle-storage',
          builder: (context, state) =>
              const Scaffold(body: Text('Immobilisation ouverte')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final listView = find.byKey(const ValueKey('action-center-scroll'));
    expect(listView, findsOneWidget);
    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);

    final storageButton = find.byKey(
      const ValueKey('action-tool-/vehicle-storage'),
    );
    await tester.scrollUntilVisible(storageButton, 220, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(storageButton, findsOneWidget);

    await tester.tap(storageButton);
    await tester.pumpAndSettle();

    expect(find.text('Immobilisation ouverte'), findsOneWidget);
    expect(find.byType(ActionCenterPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('technical control readiness action opens its direct route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/actions',
      routes: [
        GoRoute(
          path: '/actions',
          builder: (context, state) => const ActionCenterPage(),
        ),
        GoRoute(
          path: '/technical-control-readiness',
          builder: (context, state) => const Scaffold(
            body: Text('Préparation contrôle technique ouverte'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final listView = find.byKey(const ValueKey('action-center-scroll'));
    expect(listView, findsOneWidget);
    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);

    final controlButton = find.byKey(
      const ValueKey('action-tool-/technical-control-readiness'),
    );
    await tester.scrollUntilVisible(controlButton, 220, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(controlButton, findsOneWidget);

    await tester.tap(controlButton);
    await tester.pumpAndSettle();

    expect(find.text('Préparation contrôle technique ouverte'), findsOneWidget);
    expect(find.byType(ActionCenterPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
