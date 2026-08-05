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
          '/compliance',
          '/quote-comparison',
          '/insurance-review',
        ])
          GoRoute(path: path, builder: (context, state) => const Scaffold()),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsOneWidget);

    expect(find.text('Mes économies'), findsOneWidget);
    expect(find.text('Mon budget automobile'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Optimiser mon plein'),
      180,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Optimiser mon plein'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Optimiser ma recharge'),
      180,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Optimiser ma recharge'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Améliorer ma conduite'),
      180,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Améliorer ma conduite'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Réviser mon assurance'),
      180,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Réviser mon assurance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
