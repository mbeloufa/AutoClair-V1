import 'package:autoclair_app/features/home/nearby_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('nearby hub stays usable at 280 pixels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: NearbyPage()));
    await tester.pumpAndSettle();

    final listView = find.byType(ListView);
    expect(listView, findsOneWidget);
    expect(find.text('Autour de moi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.dragUntilVisible(
      find.text('Un contrôle technique'),
      listView,
      const Offset(0, -180),
      maxIteration: 20,
    );
    await tester.pumpAndSettle();

    expect(find.text('Un contrôle technique'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.dragUntilVisible(
      find.text('Une station-service'),
      listView,
      const Offset(0, 180),
      maxIteration: 20,
    );
    await tester.pumpAndSettle();

    expect(find.text('Une station-service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
