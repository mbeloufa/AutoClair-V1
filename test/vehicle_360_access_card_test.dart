import 'package:autoclair_app/features/vehicle_insights/vehicle_360_access.dart';
import 'package:autoclair_app/features/vehicle_insights/vehicle_360_access_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trial card explains the real free test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Vehicle360AccessCard(
            access: Vehicle360Access(
              authenticated: true,
              entitled: false,
              creditBalance: 0,
              trialClaimed: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1 essai gratuit disponible'), findsOneWidget);
    expect(find.textContaining('premier Bilan AutoClair 360'), findsOneWidget);
  });

  testWidgets('blocked card does not show a fake purchase button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Vehicle360AccessCard(
            access: Vehicle360Access(
              authenticated: true,
              entitled: false,
              creditBalance: 0,
              trialClaimed: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Accès Premium requis'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
