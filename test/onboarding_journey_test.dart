import 'package:autoclair_app/features/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('zigzag journey is readable at 280 pixels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: DriverJourney(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acheter'), findsOneWidget);
    expect(find.text('Entretenir'), findsOneWidget);
    expect(find.text('Réparer'), findsOneWidget);
    expect(find.text('Contrôler'), findsOneWidget);
    expect(find.text('Revendre'), findsOneWidget);
    expect(find.text('AutoClair reste à vos côtés'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
